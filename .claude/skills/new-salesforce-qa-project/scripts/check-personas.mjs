#!/usr/bin/env node
/**
 * Verify every Salesforce persona in .mcp.json can actually log in, and
 * interpret the failure when it can't.
 *
 *   node check-personas.mjs [--dir .] [--key <one-key>] [--api-version <ver>]
 *
 * The API version is DISCOVERED from the org, not hardcoded. Pass
 * --api-version only to deliberately pin an older one.
 *
 * Several Salesforce login failures look identical from the UI. This
 * separates them: an IP-range block, an org-wide SOAP toggle, and a
 * genuinely wrong password all produce different API error codes even
 * though Lightning shows "check your username and password" for all three.
 *
 * No dependencies — uses Node's built-in fetch (Node 18+).
 */

import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) out[key] = true;
    else { out[key] = next; i++; }
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));
const ROOT = resolve(String(args.dir || '.'));

// Last-resort floor, used only when the org cannot be reached to ask.
// Never raise this by hand as a "fix" — the point is that the org is
// asked at runtime, so this number stops mattering.
const FALLBACK_API_VERSION = '62.0';

/**
 * Ask the org which API versions it supports and return the newest.
 *
 * GET <instance>/services/data/ needs no authentication and returns
 * [{ label, url, version }, …] oldest-first. Discovering beats hardcoding:
 * a pinned version silently goes stale every Salesforce release, and an
 * API version older than the org's objects makes them report as
 * non-existent (see references/org-access-troubleshooting.md § 8).
 */
async function discoverApiVersion(instanceUrl) {
  try {
    const res = await fetch(`${instanceUrl.replace(/\/+$/, '')}/services/data/`, {
      headers: { Accept: 'application/json' },
    });
    if (!res.ok) return null;
    const versions = await res.json();
    if (!Array.isArray(versions) || !versions.length) return null;
    return versions
      .map((v) => v.version)
      .filter(Boolean)
      .sort((a, b) => parseFloat(a) - parseFloat(b))
      .pop();
  } catch {
    return null;
  }
}

const mcpPath = join(ROOT, '.mcp.json');
if (!existsSync(mcpPath)) {
  console.error(`\n  ✗ .mcp.json not found in ${ROOT}\n`);
  process.exit(1);
}

const mcp = JSON.parse(readFileSync(mcpPath, 'utf8'));
const servers = Object.entries(mcp.mcpServers || {}).filter(
  ([key, cfg]) => cfg?.env?.SALESFORCE_INSTANCE_URL && (!args.key || key === args.key)
);

if (!servers.length) {
  console.error('\n  ✗ No Salesforce personas found in .mcp.json\n');
  process.exit(1);
}

const xmlEscape = (s) =>
  String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const pick = (body, tag) => {
  const m = body.match(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`));
  return m ? m[1].trim() : null;
};

/** Interpret a Salesforce login error into an actionable cause. */
function interpret(code, message) {
  const blob = `${code} ${message}`;
  if (code === 'NETWORK')
    return [
      'Cannot reach the org host at all',
      'Check SALESFORCE_INSTANCE_URL for a typo, and that the host resolves — a refreshed sandbox gets a new My Domain host. Not a credentials problem.',
    ];
  if (/LOGIN_DURING_RESTRICTED_DOMAIN|restricted domain/i.test(blob))
    return [
      'Profile LOGIN IP RANGES block this machine',
      'DELETE the ranges — the standard is that profiles carry none. Setup → Profiles → [profile] → Login IP Ranges → Del on each. Must be done in the Setup UI: the Metadata API can ADD ranges but silently cannot REMOVE them. Do not add your own IP or a catch-all range instead.',
    ];
  if (/LOGIN_DURING_RESTRICTED_TIME/i.test(blob))
    return [
      'Profile LOGIN HOURS block this time of day',
      'DELETE the restriction — the standard is that profiles carry no Login Hours. Setup → Profiles → [profile] → Login Hours.',
    ];
  if (/SOAP API login\(\) is disabled|INVALID_OPERATION/i.test(blob))
    return [
      'Org-wide SOAP API login is DISABLED',
      'One Setup toggle fixes every persona at once. Ask the org owner to enable SOAP API login.',
    ];
  if (/INVALID_LOGIN/i.test(blob))
    return [
      'Credentials rejected — most often a MISSING SECURITY TOKEN',
      'If the UI login works, this is almost certainly the security token: SOAP/API logins need it appended to the password unless Setup → Security → Network Access lists this IP. Preferred fix is the Network Access range (fixes every persona at once); otherwise set SALESFORCE_PASSWORD to password+token. Other causes: wrong password, a stale MCP process holding an old one, or (rarely) a permanently broken User record — check LoginHistory: ZERO rows across every attempt means retire the user and create a new one.',
    ];
  if (/PASSWORD_LOCKOUT/i.test(blob))
    return ['User is locked out', 'Reset via Setup, or System.setPassword in anonymous Apex.'];
  if (/UNSUPPORTED_CLIENT|API_DISABLED_FOR_ORG/i.test(blob))
    return ['API access not enabled for this user/org', 'Check the "API Enabled" permission on the profile/permission set.'];
  return [code || 'Unknown error', message || ''];
}

async function loginPassword(cfg) {
  const url = `${cfg.SALESFORCE_INSTANCE_URL.replace(/\/+$/, '')}/services/Soap/u/${API_VERSION}`;
  const envelope =
    `<?xml version="1.0" encoding="utf-8"?>` +
    `<env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema"` +
    ` xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"` +
    ` xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body>` +
    `<n1:login xmlns:n1="urn:partner.soap.sforce.com">` +
    `<n1:username>${xmlEscape(cfg.SALESFORCE_USERNAME)}</n1:username>` +
    `<n1:password>${xmlEscape(cfg.SALESFORCE_PASSWORD)}</n1:password>` +
    `</n1:login></env:Body></env:Envelope>`;

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'text/xml; charset=UTF-8', SOAPAction: 'login' },
    body: envelope,
  });
  const body = await res.text();

  if (res.ok && /<sessionId>/.test(body)) {
    return { ok: true, detail: pick(body, 'userId') || '' };
  }
  return {
    ok: false,
    code: pick(body, 'sf:exceptionCode') || `HTTP ${res.status}`,
    message: pick(body, 'sf:exceptionMessage') || pick(body, 'faultstring') || body.slice(0, 200),
  };
}

async function loginClientCredentials(cfg) {
  const url = `${cfg.SALESFORCE_INSTANCE_URL.replace(/\/+$/, '')}/services/oauth2/token`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: cfg.SALESFORCE_CLIENT_ID,
      client_secret: cfg.SALESFORCE_CLIENT_SECRET,
    }),
  });
  const json = await res.json().catch(() => ({}));

  if (res.ok && json.access_token) return { ok: true, detail: json.id?.split('/').pop() || '' };
  return {
    ok: false,
    code: json.error || `HTTP ${res.status}`,
    message: json.error_description || JSON.stringify(json).slice(0, 200),
  };
}

// ------------------------------------------------------- resolve version

let API_VERSION;
let versionSource;

if (args['api-version']) {
  API_VERSION = String(args['api-version']);
  versionSource = 'pinned via --api-version';
} else {
  const instanceUrl = servers[0][1].env.SALESFORCE_INSTANCE_URL;
  const discovered = await discoverApiVersion(instanceUrl);
  if (discovered) {
    API_VERSION = discovered;
    versionSource = 'newest supported by the org';
  } else {
    API_VERSION = FALLBACK_API_VERSION;
    versionSource = 'FALLBACK — could not reach the org to ask';
  }
}

// ------------------------------------------------------------------ run

console.log(
  `\nChecking ${servers.length} persona connection(s) — API v${API_VERSION} (${versionSource})\n`
);

if (versionSource.startsWith('FALLBACK')) {
  console.log(
    `  ! Could not read ${servers[0][1].env.SALESFORCE_INSTANCE_URL}/services/data/ to\n` +
      `    discover the org's API version. Falling back to v${FALLBACK_API_VERSION}, which may be\n` +
      `    older than this org's objects — see org-access-troubleshooting.md § 8.\n` +
      `    If the host is wrong, every check below will fail for that reason alone.\n`
  );
}

let failures = 0;

for (const [key, cfg] of servers) {
  const env = cfg.env;
  const type = env.SALESFORCE_CONNECTION_TYPE || 'User_Password';
  const who = env.SALESFORCE_USERNAME || '(client credentials)';

  let result;
  try {
    result =
      type === 'OAuth_2.0_Client_Credentials'
        ? await loginClientCredentials(env)
        : await loginPassword(env);
  } catch (err) {
    result = { ok: false, code: 'NETWORK', message: err.message };
  }

  if (result.ok) {
    console.log(`  ✓ PASS  ${key}`);
    console.log(`          ${who}${result.detail ? `  →  ${result.detail}` : ''}\n`);
  } else {
    failures++;
    const [cause, fix] = interpret(result.code, result.message);
    console.log(`  ✗ FAIL  ${key}`);
    console.log(`          ${who}`);
    console.log(`          ${result.code}: ${result.message}`);
    console.log(`          CAUSE: ${cause}`);
    console.log(`          FIX:   ${fix}\n`);
  }
}

console.log(
  failures
    ? `  ${failures} of ${servers.length} failed. See the skill's references/org-access-troubleshooting.md.\n`
    : `  All ${servers.length} personas can log in.\n  Restart Claude Code if you changed .mcp.json — running servers keep their original config.\n`
);

process.exit(failures ? 1 : 0);

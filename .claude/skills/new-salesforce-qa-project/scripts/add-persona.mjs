#!/usr/bin/env node
/**
 * Register a persona in .mcp.json, .claude/settings.local.json and the
 * qa-notes.md persona table — in one step, so the three cannot drift.
 *
 * Username/password (normal personas):
 *   node add-persona.mjs --key acme-salesrep-sales-representative \
 *     --label "Sales Representative" \
 *     --username jstev@acme.com.qa --password 'Passw0rd!' \
 *     --instance-url https://acme--qa.sandbox.my.salesforce.com \
 *     [--notes "Repurposed from demo user 'Joshua Stevens'."]
 *
 * OAuth client credentials (an admin behind an MFA/passkey wall):
 *   node add-persona.mjs --key acme-admin-system-administrator \
 *     --label "System Administrator" --auth client-credentials \
 *     --client-id <id> --client-secret <secret> \
 *     --instance-url https://acme--qa.sandbox.my.salesforce.com
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
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
const AUTH = String(args.auth || 'password');

function die(msg) {
  console.error(`\n  ✗ ${msg}\n`);
  process.exit(1);
}

if (args.help || !args.key || !args.label || !args['instance-url']) {
  console.log(`
Register a Salesforce persona across .mcp.json, settings.local.json and qa-notes.md.

Required:
  --key <mcp-key>            e.g. acme-salesrep-sales-representative
  --label "Sales Rep"        Human-readable persona name
  --instance-url <url>

Auth (one of):
  --username <u> --password <p>                      (default, User_Password)
  --auth client-credentials --client-id <id> --client-secret <secret>

Optional:
  --security-token <tok>     Appended to the password. Only needed when the
                             org has no Trusted IP Range covering this machine
                             (Setup → Security → Network Access). Prefer adding
                             the range — it fixes every persona at once, and a
                             token is invalidated on every password change.
  --notes "..."              Goes in the qa-notes persona table Notes column
  --dir <path>               Project root (default: .)
`);
  process.exit(args.help ? 0 : 1);
}

const KEY = String(args.key);
const LABEL = String(args.label);
const INSTANCE_URL = String(args['instance-url']).replace(/\/+$/, '');

let env;
let usernameForTable;

if (AUTH === 'client-credentials') {
  if (!args['client-id'] || !args['client-secret']) {
    die('--auth client-credentials requires --client-id and --client-secret');
  }
  env = {
    SALESFORCE_CONNECTION_TYPE: 'OAuth_2.0_Client_Credentials',
    SALESFORCE_CLIENT_ID: String(args['client-id']),
    SALESFORCE_CLIENT_SECRET: String(args['client-secret']),
    SALESFORCE_INSTANCE_URL: INSTANCE_URL,
  };
  usernameForTable = String(args.username || '_(Connected App "Run As" user)_');
} else {
  if (!args.username || !args.password) {
    die('username/password auth requires --username and --password');
  }
  // A security token is appended directly to the password — Salesforce
  // requires it on API logins unless Network Access lists the caller's IP.
  const token = args['security-token'] ? String(args['security-token']) : '';
  env = {
    SALESFORCE_CONNECTION_TYPE: 'User_Password',
    SALESFORCE_USERNAME: String(args.username),
    SALESFORCE_PASSWORD: String(args.password) + token,
    SALESFORCE_INSTANCE_URL: INSTANCE_URL,
  };
  usernameForTable = String(args.username);
  if (token) console.log('  i security token appended to SALESFORCE_PASSWORD');
}

// ------------------------------------------------------------ .mcp.json

const mcpPath = join(ROOT, '.mcp.json');
if (!existsSync(mcpPath)) die(`.mcp.json not found in ${ROOT} — run init-sf-qa-project.mjs first`);

const mcp = JSON.parse(readFileSync(mcpPath, 'utf8'));
mcp.mcpServers ||= {};

const isUpdate = Boolean(mcp.mcpServers[KEY]);
mcp.mcpServers[KEY] = {
  command: 'npx',
  args: ['-y', '@tsmztech/mcp-server-salesforce'],
  env,
};

// keep `browser` last so the persona block reads as one group
if (mcp.mcpServers.browser) {
  const browser = mcp.mcpServers.browser;
  delete mcp.mcpServers.browser;
  mcp.mcpServers.browser = browser;
}

writeFileSync(mcpPath, JSON.stringify(mcp, null, 2) + '\n', 'utf8');
console.log(`  ${isUpdate ? '~' : '+'} .mcp.json           ${KEY}`);

// ---------------------------------------------- .claude/settings.local.json

const settingsPath = join(ROOT, '.claude', 'settings.local.json');
let settings = { enabledMcpjsonServers: [] };
if (existsSync(settingsPath)) settings = JSON.parse(readFileSync(settingsPath, 'utf8'));
settings.enabledMcpjsonServers ||= [];

if (!settings.enabledMcpjsonServers.includes(KEY)) {
  const browserIdx = settings.enabledMcpjsonServers.indexOf('browser');
  if (browserIdx === -1) settings.enabledMcpjsonServers.push(KEY);
  else settings.enabledMcpjsonServers.splice(browserIdx, 0, KEY);
  writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n', 'utf8');
  console.log(`  + settings.local.json  enabled`);
} else {
  console.log(`  = settings.local.json  already enabled`);
}

// ------------------------------------------------------------- qa-notes.md

const notesPath = join(ROOT, '.claude', 'qa-notes.md');
if (existsSync(notesPath)) {
  const notes = readFileSync(notesPath, 'utf8');
  const row = `| ${LABEL} | \`${KEY}\` | \`${usernameForTable}\` | ${args.notes || '_(fill in: repurposed from · password · profile + permission set groups · UI login status)_'} |`;

  {
    // append to the persona table: after its last contiguous table row
    const lines = notes.split('\n');
    const personaIdx = lines.findIndex((l) => /^##\s+Personas\s*$/.test(l));
    if (personaIdx === -1) {
      console.log(`  ! qa-notes.md          no "## Personas" heading — add this row by hand:\n      ${row}`);
    } else {
      let last = -1;
      for (let i = personaIdx; i < lines.length; i++) {
        if (/^##\s/.test(lines[i]) && i !== personaIdx) break;
        if (/^\|.*\|\s*$/.test(lines[i])) last = i;
      }
      // a row for this key already exists (e.g. the template's seeded
      // admin placeholder) — replace it rather than duplicating
      const existing = lines.findIndex(
        (l, i) => i >= personaIdx && /^\|/.test(l) && l.includes(`\`${KEY}\``)
      );

      if (existing !== -1) {
        lines[existing] = row;
        writeFileSync(notesPath, lines.join('\n'), 'utf8');
        console.log(`  ~ qa-notes.md          persona row updated`);
      } else if (last === -1) {
        console.log(`  ! qa-notes.md          persona table not found — add this row by hand:\n      ${row}`);
      } else {
        lines.splice(last + 1, 0, row);
        writeFileSync(notesPath, lines.join('\n'), 'utf8');
        console.log(`  + qa-notes.md          persona row appended`);
      }
    }
  }
} else {
  console.log(`  ! qa-notes.md          not found — skipped`);
}

console.log(`
  Persona "${LABEL}" registered.

  Next: verify the login, then RESTART Claude Code (an already-running
  MCP server keeps the config it started with).

      node ${join(import.meta.dirname ?? '.', 'check-personas.mjs')} --dir ${ROOT}
`);

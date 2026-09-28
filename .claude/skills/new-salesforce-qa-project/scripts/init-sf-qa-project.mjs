#!/usr/bin/env node
/**
 * Scaffold a Salesforce QA project directory.
 *
 *   node init-sf-qa-project.mjs --org-name "Acme Motors" \
 *     --instance-url https://acme--qa.sandbox.my.salesforce.com \
 *     [--org-alias Acme] [--prefix acme] [--dir .] [--dx]
 *
 * Idempotent: never overwrites an existing file. Safe to re-run on a
 * partially built project.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ASSETS = resolve(HERE, '..', 'assets');

// ---------------------------------------------------------------- args

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) {
      out[key] = true;
    } else {
      out[key] = next;
      i++;
    }
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));

if (args.help || !args['org-name'] || !args['instance-url']) {
  console.log(`
Scaffold a Salesforce QA project directory.

Required:
  --org-name "Acme Motors"       Human-readable org/client name
  --instance-url <url>           https://acme--qa.sandbox.my.salesforce.com

Optional:
  --org-alias <alias>            sf CLI alias        (default: slug of org-name)
  --prefix <prefix>              MCP key prefix      (default: first word, lowercased)
  --dir <path>                   Target directory    (default: .)
  --dx                           Also report on Salesforce DX project files
`);
  process.exit(args.help ? 0 : 1);
}

const ORG_NAME = String(args['org-name']);
const INSTANCE_URL = String(args['instance-url']).replace(/\/+$/, '');
const ORG_ALIAS = String(args['org-alias'] || ORG_NAME.replace(/[^A-Za-z0-9]+/g, '-').replace(/^-|-$/g, ''));
const PREFIX = String(args.prefix || ORG_NAME.split(/\s+/)[0].toLowerCase().replace(/[^a-z0-9]/g, ''));
const ROOT = resolve(String(args.dir || '.'));
const DATE = new Date().toISOString().slice(0, 10);

// my.salesforce.com -> lightning.force.com
const LIGHTNING_URL = INSTANCE_URL
  .replace('.my.salesforce.com', '.lightning.force.com')
  .replace(/^https?:\/\//, '');

const VARS = {
  ORG_NAME,
  INSTANCE_URL,
  LIGHTNING_URL,
  ORG_ALIAS,
  PREFIX,
  DATE,
};

// --------------------------------------------------------------- utils

const created = [];
const skipped = [];

function fill(text) {
  return text.replace(/\{\{(\w+)\}\}/g, (m, k) => (k in VARS ? VARS[k] : m));
}

function ensureDir(rel) {
  const p = join(ROOT, rel);
  if (!existsSync(p)) {
    mkdirSync(p, { recursive: true });
    created.push(`${rel}/`);
  }
  return p;
}

function writeIfAbsent(rel, content) {
  const p = join(ROOT, rel);
  if (existsSync(p)) {
    skipped.push(rel);
    return false;
  }
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, content, 'utf8');
  created.push(rel);
  return true;
}

function fromTemplate(rel, templateName) {
  const src = join(ASSETS, templateName);
  if (!existsSync(src)) {
    console.error(`  ! template missing: ${templateName}`);
    return false;
  }
  return writeIfAbsent(rel, fill(readFileSync(src, 'utf8')));
}

// ------------------------------------------------------------- scaffold

console.log(`\nScaffolding QA project for "${ORG_NAME}"`);
console.log(`  target : ${ROOT}`);
console.log(`  org    : ${INSTANCE_URL}`);
console.log(`  alias  : ${ORG_ALIAS}   prefix: ${PREFIX}\n`);

// folders, each with a .gitkeep so they survive a clone
for (const d of ['source-docs', 'test-cases', 'tickets', 'reports', 'screenshots']) {
  ensureDir(d);
  writeIfAbsent(join(d, '.gitkeep'), '');
}
ensureDir('.claude');

// .mcp.json — browser only; personas are added by add-persona.mjs
writeIfAbsent(
  '.mcp.json',
  JSON.stringify(
    {
      mcpServers: {
        browser: { command: 'npx', args: ['-y', '@playwright/mcp@latest'] },
      },
    },
    null,
    2
  ) + '\n'
);

// .claude/settings.local.json
writeIfAbsent(
  '.claude/settings.local.json',
  JSON.stringify({ enabledMcpjsonServers: ['browser'] }, null, 2) + '\n'
);

// templated docs
fromTemplate('.claude/qa-notes.md', 'qa-notes.template.md');
fromTemplate('QA-README.md', 'QA-README.template.md');

// .gitignore — append QA entries if not already present
const GITIGNORE_BLOCK = `
# --- Salesforce QA scaffold ---
.playwright-mcp/
*.session.json
`;
const giPath = join(ROOT, '.gitignore');
if (existsSync(giPath)) {
  const gi = readFileSync(giPath, 'utf8');
  if (!gi.includes('Salesforce QA scaffold')) {
    writeFileSync(giPath, gi.replace(/\s*$/, '\n') + GITIGNORE_BLOCK, 'utf8');
    created.push('.gitignore (appended)');
  } else {
    skipped.push('.gitignore (already has QA block)');
  }
} else {
  writeIfAbsent('.gitignore', GITIGNORE_BLOCK.trimStart());
}

// ------------------------------------------------------------- report

console.log('Created:');
for (const c of created) console.log(`  + ${c}`);
if (skipped.length) {
  console.log('\nAlready present (left untouched):');
  for (const s of skipped) console.log(`  = ${s}`);
}

if (args.dx) {
  console.log('\nSalesforce DX check:');
  for (const f of ['sfdx-project.json', 'force-app', '.forceignore']) {
    console.log(`  ${existsSync(join(ROOT, f)) ? '✓' : '✗'} ${f}`);
  }
  console.log('  (missing? run `sf project generate --name <name>` and re-scaffold on top)');
}

console.log(`
Next:

  1. Authorize the CLI
       sf org login web --alias ${ORG_ALIAS} --instance-url ${INSTANCE_URL}
       sf config set target-org ${ORG_ALIAS}

  1b. Discover the org's API version — never hardcode one, the CLI default
      can be older than this org's objects
       API_V=$(sf api request rest '/services/data/' --target-org ${ORG_ALIAS} \\
         | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).map(v=>v.version).sort((a,b)=>a-b).pop()")

  1c. Pull the org's metadata down (flows/validation rules/permission sets
      are invisible to the MCP layer; on disk they are greppable)
       sf project retrieve start --target-org ${ORG_ALIAS} --api-version "$API_V" \\
         --metadata Flow ValidationRule PermissionSet PermissionSetGroup \\
                    Profile RecordType CustomObject
      Record the retrieve date AND $API_V in .claude/qa-notes.md.
      Check sfdx-project.json's sourceApiVersion matches $API_V.

  1d. Org settings to confirm BEFORE adding personas:
       - Profiles carry NO Login IP Ranges and NO Login Hours (delete any;
         Setup UI only — the Metadata API cannot remove ranges)
       - Setup > Security > Network Access has a range covering this machine,
         otherwise every persona needs password+securitytoken
       - "API Enabled" is granted to each persona's permission set group

  2. Add each persona (see references/persona-provisioning.md first)
       node ${join(HERE, 'add-persona.mjs')} \\
         --key ${PREFIX}-salesrep-sales-representative \\
         --label "Sales Representative" \\
         --username <user> --password '<pass>' \\
         --instance-url ${INSTANCE_URL}

  3. Verify every login BEFORE writing test cases
       node ${join(HERE, 'check-personas.mjs')}

  4. Restart Claude Code so the MCP servers pick up .mcp.json

  5. Put the BRD/SD **PDFs** in source-docs/ and write the baseline
     section of .claude/qa-notes.md
`);

#!/usr/bin/env bash
# Completeness check for the Service Appointment QA promotion manifest.
#
#   1. Forward dependencies: everything the manifest's components reference.
#   2. Reverse dependencies: everything that references them (e.g. the ServiceAppointment
#      list-view button that launches the booking flow, the Contact layout/page holding the
#      AF_New_ServiceAppointment action).
#   3. Everything modified in DEV since <since>, so nothing touched during the SA work is missed.
#
# Any row in the "NOT IN MANIFEST" sections needs a decision: add it to package.xml, or confirm
# QA already has it (pre-existing, owned by another feature).
#
# Usage (from the project root):
#   manifests/service-appointment-qa-promotion-1007/check-completeness.sh ["ALFardan DEV"] [2026-09-01T00:00:00Z]

set -uo pipefail
ORG="${1:-ALFardan DEV}"
SINCE="${2:-2026-09-01T00:00:00Z}"
DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$DIR/package.xml"
OUT="$DIR/completeness"
mkdir -p "$OUT"

tq() { sf data query --use-tooling-api -o "$ORG" -r csv -q "$1" 2>/dev/null; }
sq() { sf data query -o "$ORG" -r csv -q "$1" 2>/dev/null; }

# Bare component names as MetadataComponentDependency reports them (fields without the object prefix).
NAMES=$(python3 - "$MANIFEST" <<'EOF'
import sys, xml.etree.ElementTree as ET
ns = '{http://soap.sforce.com/2006/04/metadata}'
names = set()
for t in ET.parse(sys.argv[1]).getroot().findall(ns + 'types'):
    for m in t.findall(ns + 'members'):
        n = m.text.split('.')[-1].split('-')[-1]
        names.add(n)
        # MetadataComponentDependency reports custom fields/objects without the __c/__mdt suffix
        names.add(n.removesuffix('__c').removesuffix('__mdt'))
print(",".join("'" + n.replace("'", "\\'") + "'" for n in sorted(names)))
EOF
)

DEP_COLS="MetadataComponentType, MetadataComponentName, RefMetadataComponentType, RefMetadataComponentName"
echo "== Forward dependencies"
tq "SELECT $DEP_COLS FROM MetadataComponentDependency WHERE MetadataComponentName IN ($NAMES)" > "$OUT/forward.csv"
echo "== Reverse dependencies"
tq "SELECT $DEP_COLS FROM MetadataComponentDependency WHERE RefMetadataComponentName IN ($NAMES)" > "$OUT/reverse.csv"

echo "== Modified since $SINCE"
{
  echo "Type,Name,LastModifiedDate,LastModifiedBy"
  tq "SELECT Name, LastModifiedDate, LastModifiedBy.Name FROM ApexClass WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/ApexClass,/'
  tq "SELECT Name, LastModifiedDate, LastModifiedBy.Name FROM ApexTrigger WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/ApexTrigger,/'
  tq "SELECT DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM FlowDefinition WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/Flow,/'
  tq "SELECT TableEnumOrId, DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM CustomField WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed -E 's/^([^,]*),([^,]*),/CustomField,\1.\2__c,/'
  tq "SELECT DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM CustomObject WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/CustomObject,/'
  tq "SELECT TableEnumOrId, Name, LastModifiedDate, LastModifiedBy.Name FROM Layout WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed -E 's/^([^,]*),([^,]*),/Layout,\1-\2,/'
  tq "SELECT DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM FlexiPage WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/FlexiPage,/'
  tq "SELECT SobjectType, DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM CompactLayout WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed -E 's/^([^,]*),([^,]*),/CompactLayout,\1.\2,/'
  tq "SELECT SobjectType, DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM QuickActionDefinition WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed -E 's/^([^,]*),([^,]*),/QuickAction,\1.\2,/'
  tq "SELECT EntityDefinitionId, Name, LastModifiedDate, LastModifiedBy.Name FROM WebLink WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed -E 's/^([^,]*),([^,]*),/WebLink,\1.\2,/'
  tq "SELECT EntityDefinitionId, ValidationName, LastModifiedDate, LastModifiedBy.Name FROM ValidationRule WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed -E 's/^([^,]*),([^,]*),/ValidationRule,\1.\2,/'
  sq "SELECT Name, LastModifiedDate, LastModifiedBy.Name FROM PermissionSet WHERE IsOwnedByProfile = false AND LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/PermissionSet,/'
  sq "SELECT DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM EmailTemplate WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/EmailTemplate,/'
  sq "SELECT DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM AF_EmailTemplateConfig__mdt WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/CustomMetadata,AF_EmailTemplateConfig__mdt./'
  sq "SELECT DeveloperName, LastModifiedDate, LastModifiedBy.Name FROM AF_BrandMailbox__mdt WHERE LastModifiedDate >= $SINCE" | tail -n +2 | sed 's/^/CustomMetadata,AF_BrandMailbox__mdt./'
} > "$OUT/modified-since.csv"

python3 - "$MANIFEST" "$OUT" <<'EOF'
import csv, sys, xml.etree.ElementTree as ET
ns = '{http://soap.sforce.com/2006/04/metadata}'
full, bare = set(), set()
for t in ET.parse(sys.argv[1]).getroot().findall(ns + 'types'):
    for m in t.findall(ns + 'members'):
        full.add(m.text.lower())
        n = m.text.split('.')[-1].split('-')[-1].lower()
        bare.update({n, n.removesuffix('__c').removesuffix('__mdt')})
out = sys.argv[2]

def section(title, rows):
    print(f"\n### {title}: {len(rows)}")
    for r in sorted(set(rows)):
        print("   ", " | ".join(r))

def deps(fname, type_col, name_col, other_type, other_name):
    try:
        rows = list(csv.DictReader(open(f"{out}/{fname}")))
    except FileNotFoundError:
        return []
    miss = []
    for r in rows:
        n = (r.get(name_col) or '').lower()
        if n and n not in bare:
            miss.append((r[type_col], r[name_col], "<-" if fname == "forward.csv" else "->",
                         r[other_type], r[other_name]))
    return miss

section("Forward dependencies NOT IN MANIFEST (component it needs <- manifest component)",
        deps("forward.csv", "RefMetadataComponentType", "RefMetadataComponentName",
             "MetadataComponentType", "MetadataComponentName"))
section("Reverse dependencies NOT IN MANIFEST (component that uses -> manifest component)",
        deps("reverse.csv", "MetadataComponentType", "MetadataComponentName",
             "RefMetadataComponentType", "RefMetadataComponentName"))

miss = []
try:
    for r in csv.reader(open(f"{out}/modified-since.csv")):
        if len(r) < 2 or r[0] == "Type":
            continue
        name = r[1]
        if name.lower() not in full and name.split('.')[-1].split('-')[-1].lower() not in bare:
            miss.append(tuple(r))
except FileNotFoundError:
    pass
section("Modified in DEV since the cut-off date, NOT IN MANIFEST (review: SA-related or another feature?)", miss)
print(f"\nRaw CSVs: {out}/")
EOF

#!/bin/bash
# REST calls as a named persona (SOAP username/password login, session cached).
#   sfp.sh <persona> query "SELECT ..."
#   sfp.sh <persona> get   /services/data/vXX.X/sobjects/Opportunity/006...
#   sfp.sh <persona> post  /services/data/vXX.X/sobjects/Opportunity '{"Name":"x"}'
#   sfp.sh <persona> patch /services/data/vXX.X/sobjects/Opportunity/006... '{"StageName":"x"}'
#   sfp.sh <persona> del   /services/data/vXX.X/sobjects/Opportunity/006...
# Personas come from a git-ignored file (default: .claude/personas.conf), one per line:
#   <key>|<username>|<password>[|<security token>]
# Env: QA_PERSONAS_FILE, SF_LOGIN_URL (default https://test.salesforce.com), SF_API_VERSION (default 62.0)
set -u
PERSONA="${1:?persona}"; ACTION="${2:?action}"; ARG="${3:-}"; BODY="${4:-}"
CONF="${QA_PERSONAS_FILE:-.claude/personas.conf}"
LOGIN_URL="${SF_LOGIN_URL:-https://test.salesforce.com}"
API="${SF_API_VERSION:-62.0}"
LINE=$(grep -E "^${PERSONA}\|" "$CONF" 2>/dev/null | head -1)
[ -n "$LINE" ] || { echo "persona '$PERSONA' not found in $CONF" >&2; exit 2; }
U=$(echo "$LINE" | cut -d'|' -f2); P=$(echo "$LINE" | cut -d'|' -f3); T=$(echo "$LINE" | cut -d'|' -f4)
CACHE_DIR="${TMPDIR:-/tmp}/sfp-sessions"; mkdir -p "$CACHE_DIR"; CACHE="$CACHE_DIR/$PERSONA"

xmlesc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

login() {
  local u p env r
  u=$(printf '%s' "$U" | xmlesc); p=$(printf '%s%s' "$P" "$T" | xmlesc)
  env="<?xml version=\"1.0\" encoding=\"utf-8\"?><env:Envelope xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\"><env:Body><n1:login xmlns:n1=\"urn:partner.soap.sforce.com\"><n1:username>$u</n1:username><n1:password>$p</n1:password></n1:login></env:Body></env:Envelope>"
  r=$(curl -s "$LOGIN_URL/services/Soap/u/$API" -H "Content-Type: text/xml; charset=UTF-8" -H "SOAPAction: login" -d "$env")
  if echo "$r" | grep -q "<sessionId>"; then
    printf '%s\n%s\n' \
      "$(echo "$r" | grep -o '<serverUrl>[^<]*' | sed 's/<serverUrl>//; s|/services.*||')" \
      "$(echo "$r" | grep -o '<sessionId>[^<]*' | sed 's/<sessionId>//')" > "$CACHE"
    return 0
  fi
  echo "LOGIN FAILED ($PERSONA): $(echo "$r" | grep -o '<faultstring>[^<]*' | sed 's/<faultstring>//')" >&2
  return 1
}

call() {
  local URL SID
  URL=$(sed -n 1p "$CACHE"); SID=$(sed -n 2p "$CACHE")
  case "$ACTION" in
    query) curl -s -G "$URL/services/data/v$API/query" --data-urlencode "q=$ARG" -H "Authorization: Bearer $SID";;
    get)   curl -s "$URL$ARG" -H "Authorization: Bearer $SID";;
    post)  curl -s -X POST "$URL$ARG" -H "Authorization: Bearer $SID" -H "Content-Type: application/json" -d "$BODY";;
    patch) curl -s -w '\nHTTP %{http_code}' -X PATCH "$URL$ARG" -H "Authorization: Bearer $SID" -H "Content-Type: application/json" -d "$BODY";;
    del)   curl -s -w '\nHTTP %{http_code}' -X DELETE "$URL$ARG" -H "Authorization: Bearer $SID";;
    *) echo "unknown action $ACTION" >&2; exit 2;;
  esac
}

[ -s "$CACHE" ] || login || exit 1
OUT=$(call)
if echo "$OUT" | grep -q "INVALID_SESSION_ID"; then login || exit 1; OUT=$(call); fi
echo "$OUT"

#!/bin/bash
# REST calls as the admin user the sf CLI is authorised as.
#   sfa.sh query "SELECT ..."
#   sfa.sh get|del   /services/data/vXX.X/sobjects/X/ID
#   sfa.sh post|patch /services/data/vXX.X/sobjects/X[/ID] '{...}'
# Env: SF_ORG (sf CLI alias, required)
set -u
ORG="${SF_ORG:?set SF_ORG to the sf CLI org alias}"
ACTION="${1:?action}"; ARG="${2:-}"; BODY="${3:-}"
case "$ACTION" in
  query) sf data query -o "$ORG" -q "$ARG" --json;;
  get)   sf api request rest "$ARG" -o "$ORG";;
  post)  sf api request rest "$ARG" -o "$ORG" --method POST --body "$BODY";;
  patch) sf api request rest "$ARG" -o "$ORG" --method PATCH --body "$BODY";;
  del)   sf api request rest "$ARG" -o "$ORG" --method DELETE;;
  *) echo "unknown action $ACTION" >&2; exit 2;;
esac

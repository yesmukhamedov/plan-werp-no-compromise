#!/usr/bin/env bash
# Plan integrity check.
# Runs locally and in CI on every PR.
#
#   ./tools/validate.sh
#
# Checks:
#   1. frontmatter in docs/, product/, transition/, backlog/
#   2. uniqueness of identifiers
#   3. internal links point at existing files
#   4. absence of sensitive data (the repository is public)
#   5. ADR statuses; completeness of the ADR and epic registries
#   5.3 the product/ and transition/ split:
#       - product/ does not mention the legacy (it describes only the target system)
#       - the mappings link into product/
#   6. absence of unfilled template placeholders outside templates/

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

errors=0
warnings=0

err()  { printf '  \033[31mERROR\033[0m   %s\n' "$1"; errors=$((errors + 1)); }
warn() { printf '  \033[33mWARNING\033[0m %s\n' "$1"; warnings=$((warnings + 1)); }
ok()   { printf '  \033[32mOK\033[0m      %s\n' "$1"; }
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

docs=$(find docs product transition backlog -name '*.md' -type f | sort)

# ---------------------------------------------------------------- 1. frontmatter
section '1. Frontmatter'

missing_fm=0
for f in $docs; do
  case "$f" in */README.md) ;; esac
  if [ "$(head -1 "$f")" != "---" ]; then
    err "$f: no frontmatter"
    missing_fm=1
    continue
  fi
  for field in id title status; do
    if ! sed -n '2,/^---$/p' "$f" | grep -q "^${field}:"; then
      err "$f: the frontmatter has no '$field' field"
      missing_fm=1
    fi
  done
done
[ $missing_fm -eq 0 ] && ok "frontmatter is present in every document"

# ------------------------------------------------------- 2. uniqueness of ids
section '2. Uniqueness of identifiers'

dup=$(for f in $docs; do
        sed -n '2,/^---$/p' "$f" | grep '^id:' | head -1 | sed 's/^id: *//'
      done | sort | uniq -d)

if [ -n "$dup" ]; then
  echo "$dup" | while read -r d; do err "identifier '$d' is used more than once"; done
else
  ok "the identifiers are unique"
fi

# Uniqueness of the ADR numbers by file name
adr_dup=$(ls docs/02-decisions/ADR-*.md 2>/dev/null \
          | sed 's|.*/\(ADR-[0-9]*\).*|\1|' | sort | uniq -d)
[ -n "$adr_dup" ] && err "duplicate ADR numbers: $adr_dup"

epic_dup=$(ls backlog/EPIC-*.md 2>/dev/null \
           | sed 's|.*/\(EPIC-[0-9]*\).*|\1|' | sort | uniq -d)
[ -n "$epic_dup" ] && err "duplicate epic numbers: $epic_dup"

# ------------------------------------------------------ 3. internal links
section '3. Internal links'

broken=0
for f in $(find . -name '*.md' -not -path './.git/*' | sort); do
  dir=$(dirname "$f")
  # markdown links to .md, without anchors and without external schemes
  grep -o '](\([^)]*\.md\)[^)]*)' "$f" 2>/dev/null \
    | sed 's/^](//; s/[)#].*$//' \
    | while read -r link; do
        case "$link" in
          http*|mailto:*|'') continue ;;
        esac
        if [ ! -f "$dir/$link" ]; then
          printf '  \033[31mERROR\033[0m   %s -> %s (file not found)\n' "$f" "$link"
          echo x >> /tmp/plan_validate_broken.$$
        fi
      done
done
if [ -f /tmp/plan_validate_broken.$$ ]; then
  broken=$(wc -l < /tmp/plan_validate_broken.$$)
  errors=$((errors + broken))
  rm -f /tmp/plan_validate_broken.$$
else
  ok "no broken internal links"
fi

# ------------------------------------------- 4. sensitive data
section '4. Sensitive data (the repository is public)'

leak=0

# private IP addresses
if grep -rInE '\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}\b' \
     --include='*.md' --include='*.yml' --include='*.sh' . 2>/dev/null \
     | grep -v '^\./tools/validate.sh'; then
  err "an internal IP address was found — replace it with <internal-host>"
  leak=1
fi

# common secret patterns
if grep -rInE '(password|passwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'<>${}]{6,}' \
     --include='*.md' --include='*.yml' . 2>/dev/null \
     | grep -v '^\./tools/validate.sh'; then
  err "this looks like a secret in the clear"
  leak=1
fi

# private keys
if grep -rIl --exclude-dir=.git --exclude='validate.sh' -e '-----BEGIN' . 2>/dev/null | grep .; then
  err "a block that looks like a private key or a certificate was found"
  leak=1
fi

[ $leak -eq 0 ] && ok "no known sensitive-data patterns were found"
warn "the automated check catches known patterns, not everything — see CONTRIBUTING.md"

# ----------------------------------------------------------- 5. ADR statuses
section '5. ADR statuses'

bad_status=0
for f in docs/02-decisions/ADR-*.md; do
  [ -f "$f" ] || continue
  st=$(sed -n '2,/^---$/p' "$f" | grep '^status:' | head -1 | sed 's/^status: *//')
  case "$st" in
    Proposed|Accepted|Deferred|Superseded|Rejected) ;;
    *) err "$f: invalid status '$st'"; bad_status=1 ;;
  esac
done
[ $bad_status -eq 0 ] && ok "the ADR statuses are valid"

# ADRs in the registry
section '5.1. ADRs in the decision registry'
for f in docs/02-decisions/ADR-*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  grep -q "$base" docs/02-decisions/README.md \
    || err "$base is missing from the registry in docs/02-decisions/README.md"
done
ok "every ADR is listed in the registry"

# epics in the registry
section '5.2. Epics in the backlog registry'
for f in backlog/EPIC-*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  grep -q "$base" backlog/README.md \
    || err "$base is missing from the registry in backlog/README.md"
done
ok "every epic is listed in the registry"

# -------------------------------------- 5.3. the product / transition split
section '5.3. The product / transition split'

# product/ describes ONLY the target system. Mentions of the legacy belong to
# transition/ or docs/00-context/. The section's README explains the rule itself
# and is therefore excluded.
if grep -rIn -i --exclude='README.md' \
     -e 'legacy' -e 'inherited' \
     -e 'werp_jsf' -e 'werp_java_back' -e 'werp_react' \
     -e 'werp_crm' -e 'werp_call_center' \
     -e 'current system' -e 'the current state' \
     product/ 2>/dev/null; then
  err "product/ describes the target system: mentions of the legacy move to transition/ (see CONTRIBUTING.md)"
else
  ok "product/ contains no mentions of the legacy"
fi

# transition/ must link into product/ — otherwise it describes the target itself
# instead of linking to it.
missing_ref=0
for f in transition/01-database-mapping.md transition/02-backend-mapping.md          transition/03-api-mapping.md transition/04-frontend-mapping.md          transition/map/D*.md; do
  [ -f "$f" ] || continue
  grep -q 'product/' "$f" || { err "$f: not a single link into product/ — a map must connect the source with the target"; missing_ref=1; }
done
[ $missing_ref -eq 0 ] && ok "the mappings link into product/"

# --------------------------------------------------- 6. template leftovers
section '6. Unfilled template placeholders'

# Placeholders are searched for only where they mean an unfilled template:
# in the frontmatter (id/title/date) and in angle brackets in the text.
# The YYYY-MM-DD date format and the "ADR-NNNN-name.md" instruction in a README
# are not placeholders.
if grep -rIn -e '^id: *\(ADR-NNNN\|EPIC-NNN\|TASK-NNNN\)' \
              -e '^title: *<' \
              -e '^date: *YYYY-MM-DD' \
              -e '<short decision name>' \
     docs product transition backlog 2>/dev/null; then
  err "template placeholders are still present in the documents"
else
  ok "no placeholders"
fi

# ------------------------------------------------------------------ summary
section 'Summary'
printf '  documents: %s\n' "$(echo "$docs" | wc -l | tr -d ' ')"
printf '  errors:    %s\n' "$errors"
printf '  warnings:  %s\n' "$warnings"

if [ "$errors" -gt 0 ]; then
  printf '\n\033[31mCheck failed.\033[0m\n'
  exit 1
fi
printf '\n\033[32mCheck passed.\033[0m\n'

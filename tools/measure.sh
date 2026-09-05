#!/usr/bin/env bash
# Recompute the metrics of the legacy repositories.
#
#   ./tools/measure.sh <path-to-the-folder-with-the-repositories>
#
# Reproduces the numbers in docs/00-context/01-inventory.md. Run it when the
# inventory is refreshed: the plan is assessed relative to these numbers
# (see CONTRIBUTING.md — "Numbers come from measurements").
#
# The output goes to the terminal; copy it into 01-inventory.md by hand, updating
# the measured_at field.

set -uo pipefail

root="${1:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  echo "Usage: $0 <path-to-the-folder-with-the-legacy-repositories>" >&2
  exit 1
fi

hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }

count_files() { find "$1" -name "$2" -type f 2>/dev/null | wc -l | tr -d ' '; }
count_lines() { find "$1" -name "$2" -type f -exec cat {} + 2>/dev/null | wc -l | tr -d ' '; }

# ------------------------------------------------------------ per repository
hdr 'Java repositories: files and lines'
for repo in werp_jsf werp_java_back_v2 werp_crm werp_call_center; do
  d="$root/$repo"
  [ -d "$d" ] || continue
  printf '  %-22s files=%-6s lines=%s\n' \
    "$repo" "$(count_files "$d" '*.java')" "$(count_lines "$d" '*.java')"
done

hdr 'Frontend: files and lines'
d="$root/werp_react_front/src"
if [ -d "$d" ]; then
  js=$(find "$d" -type f \( -name '*.js' -o -name '*.jsx' \) | wc -l | tr -d ' ')
  ts=$(find "$d" -type f \( -name '*.ts' -o -name '*.tsx' \) | wc -l | tr -d ' ')
  ln=$(find "$d" -type f \( -name '*.js' -o -name '*.jsx' \) -exec cat {} + | wc -l | tr -d ' ')
  printf '  js/jsx=%-6s ts/tsx=%-4s lines=%s\n' "$js" "$ts" "$ln"
fi

hdr 'bridge (Go)'
d="$root/bridge"
if [ -d "$d" ]; then
  printf '  files=%-6s lines=%-8s tests=%s\n' \
    "$(count_files "$d" '*.go')" "$(count_lines "$d" '*.go')" \
    "$(count_files "$d" '*_test.go')"
fi

# ------------------------------------------------ modules of the main backend
back="$root/werp_java_back_v2"
if [ -d "$back" ]; then
  hdr 'werp_java_back_v2: modules'
  for m in core service crm main-module util scheduler auth-server; do
    [ -d "$back/$m" ] || continue
    printf '  %-14s files=%-6s lines=%s\n' \
      "$m" "$(count_files "$back/$m" '*.java')" "$(count_lines "$back/$m" '*.java')"
  done

  hdr 'werp_java_back_v2: subject areas of core'
  for d in "$back"/core/src/main/java/kz/aura/werp/core/*/; do
    [ -d "$d" ] || continue
    printf '  %-16s files=%-6s lines=%s\n' \
      "$(basename "$d")" "$(count_files "$d" '*.java')" "$(count_lines "$d" '*.java')"
  done

  hdr 'werp_java_back_v2: API surface and model'
  cd "$back" || exit 1
  printf '  endpoints:           %s\n' "$(grep -rE '@(Get|Post|Put|Delete|Patch)Mapping' --include='*.java' . | wc -l | tr -d ' ')"
  for m in Get Post Put Delete Patch; do
    printf '    %-7s %s\n' "$m" "$(grep -r "@${m}Mapping" --include='*.java' . | wc -l | tr -d ' ')"
  done
  printf '  @RequestMapping:     %s\n' "$(grep -r '@RequestMapping' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  controllers:         %s\n' "$(grep -rlE '@(Rest)?Controller' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  @Service:            %s\n' "$(grep -rl '@Service' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  @Entity:             %s\n' "$(grep -rl '@Entity' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  repositories:        %s\n' "$(grep -rl 'extends JpaRepository\|extends CrudRepository\|extends PagingAndSorting' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  @Query:              %s\n' "$(grep -r '@Query' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  nativeQuery=true:    %s\n' "$(grep -r 'nativeQuery *= *true' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  createQuery:         %s\n' "$(grep -r 'createQuery' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  createNativeQuery:   %s\n' "$(grep -r 'createNativeQuery' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  JdbcTemplate:        %s\n' "$(grep -r 'JdbcTemplate' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  @Transactional:      %s\n' "$(grep -r '@Transactional' --include='*.java' . | wc -l | tr -d ' ')"

  hdr 'werp_java_back_v2: quality indicators'
  printf '  test files:          %s\n' "$(find . -path '*/src/test/*' -name '*.java' | wc -l | tr -d ' ')"
  printf '  System.out.print*:   %s\n' "$(grep -r 'System.out.print' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  printStackTrace:     %s\n' "$(grep -r 'printStackTrace' --include='*.java' . | wc -l | tr -d ' ')"
  printf '\n  classes with >15 @Autowired:\n'
  grep -rc '@Autowired' --include='*.java' . | awk -F: '$2>15 {printf "    %4d  %s\n", $2, $1}' | sort -rn | head -10
fi

printf '\nCopy the numbers into docs/00-context/01-inventory.md, updating measured_at.\n'

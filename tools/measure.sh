#!/usr/bin/env bash
# Пересчёт метрик легаси-репозиториев.
#
#   ./tools/measure.sh <путь-к-папке-с-репозиториями>
#
# Воспроизводит числа из docs/00-context/01-inventory.md. Запускать при
# обновлении инвентаризации: план оценивается относительно этих чисел
# (см. CONTRIBUTING.md — «Числа берутся из измерений»).
#
# Вывод — в терминал; переносить в 01-inventory.md вручную, с обновлением
# поля measured_at.

set -uo pipefail

root="${1:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  echo "Использование: $0 <путь-к-папке-с-репозиториями legacy>" >&2
  exit 1
fi

hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }

count_files() { find "$1" -name "$2" -type f 2>/dev/null | wc -l | tr -d ' '; }
count_lines() { find "$1" -name "$2" -type f -exec cat {} + 2>/dev/null | wc -l | tr -d ' '; }

# --------------------------------------------------------- по репозиториям
hdr 'Java-репозитории: файлы и строки'
for repo in werp_jsf werp_java_back_v2 werp_crm werp_call_center; do
  d="$root/$repo"
  [ -d "$d" ] || continue
  printf '  %-22s файлов=%-6s строк=%s\n' \
    "$repo" "$(count_files "$d" '*.java')" "$(count_lines "$d" '*.java')"
done

hdr 'Фронтенд: файлы и строки'
d="$root/werp_react_front/src"
if [ -d "$d" ]; then
  js=$(find "$d" -type f \( -name '*.js' -o -name '*.jsx' \) | wc -l | tr -d ' ')
  ts=$(find "$d" -type f \( -name '*.ts' -o -name '*.tsx' \) | wc -l | tr -d ' ')
  ln=$(find "$d" -type f \( -name '*.js' -o -name '*.jsx' \) -exec cat {} + | wc -l | tr -d ' ')
  printf '  js/jsx=%-6s ts/tsx=%-4s строк=%s\n' "$js" "$ts" "$ln"
fi

hdr 'bridge (Go)'
d="$root/bridge"
if [ -d "$d" ]; then
  printf '  файлов=%-6s строк=%-8s тестов=%s\n' \
    "$(count_files "$d" '*.go')" "$(count_lines "$d" '*.go')" \
    "$(count_files "$d" '*_test.go')"
fi

# ------------------------------------------------- модули основного бэкенда
back="$root/werp_java_back_v2"
if [ -d "$back" ]; then
  hdr 'werp_java_back_v2: модули'
  for m in core service crm main-module util scheduler auth-server; do
    [ -d "$back/$m" ] || continue
    printf '  %-14s файлов=%-6s строк=%s\n' \
      "$m" "$(count_files "$back/$m" '*.java')" "$(count_lines "$back/$m" '*.java')"
  done

  hdr 'werp_java_back_v2: предметные области core'
  for d in "$back"/core/src/main/java/kz/aura/werp/core/*/; do
    [ -d "$d" ] || continue
    printf '  %-16s файлов=%-6s строк=%s\n' \
      "$(basename "$d")" "$(count_files "$d" '*.java')" "$(count_lines "$d" '*.java')"
  done

  hdr 'werp_java_back_v2: поверхность API и модель'
  cd "$back" || exit 1
  printf '  эндпойнтов:          %s\n' "$(grep -rE '@(Get|Post|Put|Delete|Patch)Mapping' --include='*.java' . | wc -l | tr -d ' ')"
  for m in Get Post Put Delete Patch; do
    printf '    %-7s %s\n' "$m" "$(grep -r "@${m}Mapping" --include='*.java' . | wc -l | tr -d ' ')"
  done
  printf '  @RequestMapping:     %s\n' "$(grep -r '@RequestMapping' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  контроллеров:        %s\n' "$(grep -rlE '@(Rest)?Controller' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  @Service:            %s\n' "$(grep -rl '@Service' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  @Entity:             %s\n' "$(grep -rl '@Entity' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  репозиториев:        %s\n' "$(grep -rl 'extends JpaRepository\|extends CrudRepository\|extends PagingAndSorting' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  @Query:              %s\n' "$(grep -r '@Query' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  nativeQuery=true:    %s\n' "$(grep -r 'nativeQuery *= *true' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  createQuery:         %s\n' "$(grep -r 'createQuery' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  createNativeQuery:   %s\n' "$(grep -r 'createNativeQuery' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  JdbcTemplate:        %s\n' "$(grep -r 'JdbcTemplate' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  @Transactional:      %s\n' "$(grep -r '@Transactional' --include='*.java' . | wc -l | tr -d ' ')"

  hdr 'werp_java_back_v2: индикаторы качества'
  printf '  тестовых файлов:     %s\n' "$(find . -path '*/src/test/*' -name '*.java' | wc -l | tr -d ' ')"
  printf '  System.out.print*:   %s\n' "$(grep -r 'System.out.print' --include='*.java' . | wc -l | tr -d ' ')"
  printf '  printStackTrace:     %s\n' "$(grep -r 'printStackTrace' --include='*.java' . | wc -l | tr -d ' ')"
  printf '\n  классы с >15 @Autowired:\n'
  grep -rc '@Autowired' --include='*.java' . | awk -F: '$2>15 {printf "    %4d  %s\n", $2, $1}' | sort -rn | head -10
fi

printf '\nЧисла перенести в docs/00-context/01-inventory.md, обновив measured_at.\n'

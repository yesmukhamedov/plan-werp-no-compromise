#!/usr/bin/env bash
# Проверка целостности плана.
# Запускается локально и в CI на каждый PR.
#
#   ./tools/validate.sh
#
# Проверяет:
#   1. frontmatter в docs/, product/, transition/, backlog/
#   2. уникальность идентификаторов
#   3. внутренние ссылки на существующие файлы
#   4. отсутствие чувствительных данных (репозиторий публичный)
#   5. статусы ADR; полноту реестров ADR и эпиков
#   5.3 разделение product/ и transition/:
#       - product/ не упоминает легаси (описывает только целевую систему)
#       - карты соответствий ссылаются на product/
#   6. отсутствие незаполненных плейсхолдеров шаблонов вне templates/

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

errors=0
warnings=0

err()  { printf '  \033[31mОШИБКА\033[0m  %s\n' "$1"; errors=$((errors + 1)); }
warn() { printf '  \033[33mВНИМАНИЕ\033[0m %s\n' "$1"; warnings=$((warnings + 1)); }
ok()   { printf '  \033[32mOK\033[0m      %s\n' "$1"; }
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

docs=$(find docs product transition backlog -name '*.md' -type f | sort)

# ---------------------------------------------------------------- 1. frontmatter
section '1. Frontmatter'

missing_fm=0
for f in $docs; do
  case "$f" in */README.md) ;; esac
  if [ "$(head -1 "$f")" != "---" ]; then
    err "$f: нет frontmatter"
    missing_fm=1
    continue
  fi
  for field in id title status; do
    if ! sed -n '2,/^---$/p' "$f" | grep -q "^${field}:"; then
      err "$f: во frontmatter нет поля '$field'"
      missing_fm=1
    fi
  done
done
[ $missing_fm -eq 0 ] && ok "frontmatter на месте во всех документах"

# ------------------------------------------------------- 2. уникальность id
section '2. Уникальность идентификаторов'

dup=$(for f in $docs; do
        sed -n '2,/^---$/p' "$f" | grep '^id:' | head -1 | sed 's/^id: *//'
      done | sort | uniq -d)

if [ -n "$dup" ]; then
  echo "$dup" | while read -r d; do err "идентификатор '$d' используется более одного раза"; done
else
  ok "идентификаторы уникальны"
fi

# Уникальность ADR-номеров по именам файлов
adr_dup=$(ls docs/02-decisions/ADR-*.md 2>/dev/null \
          | sed 's|.*/\(ADR-[0-9]*\).*|\1|' | sort | uniq -d)
[ -n "$adr_dup" ] && err "повторяющиеся номера ADR: $adr_dup"

epic_dup=$(ls backlog/EPIC-*.md 2>/dev/null \
           | sed 's|.*/\(EPIC-[0-9]*\).*|\1|' | sort | uniq -d)
[ -n "$epic_dup" ] && err "повторяющиеся номера эпиков: $epic_dup"

# ------------------------------------------------------ 3. внутренние ссылки
section '3. Внутренние ссылки'

broken=0
for f in $(find . -name '*.md' -not -path './.git/*' | sort); do
  dir=$(dirname "$f")
  # markdown-ссылки на .md, без якорей и без внешних схем
  grep -o '](\([^)]*\.md\)[^)]*)' "$f" 2>/dev/null \
    | sed 's/^](//; s/[)#].*$//' \
    | while read -r link; do
        case "$link" in
          http*|mailto:*|'') continue ;;
        esac
        if [ ! -f "$dir/$link" ]; then
          printf '  \033[31mОШИБКА\033[0m  %s -> %s (файл не найден)\n' "$f" "$link"
          echo x >> /tmp/plan_validate_broken.$$
        fi
      done
done
if [ -f /tmp/plan_validate_broken.$$ ]; then
  broken=$(wc -l < /tmp/plan_validate_broken.$$)
  errors=$((errors + broken))
  rm -f /tmp/plan_validate_broken.$$
else
  ok "битых внутренних ссылок нет"
fi

# ------------------------------------------- 4. чувствительные данные
section '4. Чувствительные данные (репозиторий публичный)'

leak=0

# приватные IP-адреса
if grep -rInE '\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}\b' \
     --include='*.md' --include='*.yml' --include='*.sh' . 2>/dev/null \
     | grep -v '^\./tools/validate.sh'; then
  err "найден внутренний IP-адрес — заменить на <internal-host>"
  leak=1
fi

# распространённые шаблоны секретов
if grep -rInE '(password|passwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'<>${}]{6,}' \
     --include='*.md' --include='*.yml' . 2>/dev/null \
     | grep -v '^\./tools/validate.sh'; then
  err "похоже на секрет в открытом виде"
  leak=1
fi

# приватные ключи
if grep -rIl --exclude-dir=.git --exclude='validate.sh' -e '-----BEGIN' . 2>/dev/null | grep .; then
  err "найден блок, похожий на приватный ключ или сертификат"
  leak=1
fi

[ $leak -eq 0 ] && ok "известных шаблонов чувствительных данных не найдено"
warn "автоматическая проверка ловит известные шаблоны, а не всё — см. CONTRIBUTING.md"

# ----------------------------------------------------------- 5. статусы ADR
section '5. Статусы ADR'

bad_status=0
for f in docs/02-decisions/ADR-*.md; do
  [ -f "$f" ] || continue
  st=$(sed -n '2,/^---$/p' "$f" | grep '^status:' | head -1 | sed 's/^status: *//')
  case "$st" in
    Предложено|Принято|Отложено|Заменено|Отвергнуто) ;;
    *) err "$f: недопустимый статус '$st'"; bad_status=1 ;;
  esac
done
[ $bad_status -eq 0 ] && ok "статусы ADR корректны"

# ADR в реестре
section '5.1. ADR в реестре решений'
for f in docs/02-decisions/ADR-*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  grep -q "$base" docs/02-decisions/README.md \
    || err "$base отсутствует в реестре docs/02-decisions/README.md"
done
ok "все ADR перечислены в реестре"

# эпики в реестре
section '5.2. Эпики в реестре бэклога'
for f in backlog/EPIC-*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  grep -q "$base" backlog/README.md \
    || err "$base отсутствует в реестре backlog/README.md"
done
ok "все эпики перечислены в реестре"

# -------------------------------------- 5.3. разделение product / transition
section '5.3. Разделение product / transition'

# product/ описывает ТОЛЬКО целевую систему. Упоминания легаси относятся к
# transition/ или docs/00-context/. README раздела объясняет само правило и
# потому исключён.
if grep -rIn -i --exclude='README.md' \
     -e 'легаси' -e 'унаследован' \
     -e 'werp_jsf' -e 'werp_java_back' -e 'werp_react' \
     -e 'werp_crm' -e 'werp_call_center' \
     -e 'текущей систем' -e 'текущая систем' -e 'Текущее состояние' \
     product/ 2>/dev/null; then
  err "product/ описывает целевую систему: упоминания легаси переносятся в transition/ (см. CONTRIBUTING.md)"
else
  ok "product/ не содержит упоминаний легаси"
fi

# transition/ обязан ссылаться на product/ — иначе он описывает цель сам,
# вместо того чтобы связывать с ней.
missing_ref=0
for f in transition/01-database-mapping.md transition/02-backend-mapping.md          transition/03-api-mapping.md transition/04-frontend-mapping.md          transition/map/D*.md; do
  [ -f "$f" ] || continue
  grep -q 'product/' "$f" || { err "$f: нет ни одной ссылки в product/ — карта обязана связывать источник с целью"; missing_ref=1; }
done
[ $missing_ref -eq 0 ] && ok "карты соответствий ссылаются на product/"

# --------------------------------------------------- 6. остатки шаблонов
section '6. Незаполненные плейсхолдеры шаблонов'

# Ищем плейсхолдеры только там, где они означают незаполненный шаблон:
# во frontmatter (id/title/date) и в угловых скобках в тексте.
# Формат даты YYYY-MM-DD и инструкция «ADR-NNNN-имя.md» в README — не плейсхолдеры.
if grep -rIn -e '^id: *\(ADR-NNNN\|EPIC-NNN\|TASK-NNNN\)' \
              -e '^title: *<' \
              -e '^date: *YYYY-MM-DD' \
              -e '<краткое имя решения>' \
     docs product transition backlog 2>/dev/null; then
  err "в документах остались плейсхолдеры из шаблонов"
else
  ok "плейсхолдеров нет"
fi

# ------------------------------------------------------------------ итог
section 'Итог'
printf '  документов: %s\n' "$(echo "$docs" | wc -l | tr -d ' ')"
printf '  ошибок:     %s\n' "$errors"
printf '  замечаний:  %s\n' "$warnings"

if [ "$errors" -gt 0 ]; then
  printf '\n\033[31mПроверка не пройдена.\033[0m\n'
  exit 1
fi
printf '\n\033[32mПроверка пройдена.\033[0m\n'

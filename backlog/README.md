---
id: BACKLOG
title: Бэклог
status: actual
---

# Бэклог

Фазы плана разложены на эпики, эпики — на задачи. Один эпик — один файл.

Шаблоны: [templates/EPIC.md](../templates/EPIC.md), [templates/TASK.md](../templates/TASK.md).

## Эпики Фазы 0

Все эпики ниже — работы [Фазы 0](../transition/plan/01-phase-0-foundation.md),
закрывающие гейт [G0](../transition/plan/00-roadmap.md#g0--конец-фазы-0).
Они **стек-независимы** и выполняются, пока решается
[ADR-0003](../docs/02-decisions/ADR-0003-backend-stack.md).

| # | Эпик | Закрывает | Блокирует |
|---|---|---|---|
| [EPIC-001](EPIC-001-project-setup.md) | Организация проекта | — | все остальные |
| [EPIC-002](EPIC-002-contract-inventory.md) | Инвентаризация контрактов API | G0 | ADR-0003, Фазы 1–3 |
| [EPIC-003](EPIC-003-schema-inventory.md) | Инвентаризация схемы БД | G0, OQ-007 | ADR-0003, миграция данных |
| [EPIC-004](EPIC-004-characterization-tests.md) | Характеризационные тесты | G0 | D5, D6 в Фазе 2 |
| [EPIC-005](EPIC-005-data-migration.md) | Инструмент миграции данных | — | Фаза 4 (стартует после G1) |
| [EPIC-006](EPIC-006-permissions-inventory.md) | Инвентаризация ролей и прав | G0 | ADR-0006 |
| [EPIC-007](EPIC-007-reports-inventory.md) | Инвентаризация отчётов | G0 | ADR-0009, оценки |
| [EPIC-008](EPIC-008-i18n-migration.md) | Перенос многоязычности | — | Фаза 3 |
| [EPIC-009](EPIC-009-baseline-measurement.md) | Измерение базовых показателей | G0 | НФТ |
| [EPIC-010](EPIC-010-security-audit.md) | Аудит безопасности легаси | G0 | приоритеты плана |
| [EPIC-011](EPIC-011-scenario-registry.md) | Реестр бизнес-сценариев | G0 | тесты, паритет, приёмка |

## Порядок

```
EPIC-001 ──┬─► EPIC-002 ──┬─► EPIC-004
           ├─► EPIC-003 ──┴─► EPIC-005 (начало после G1)
           ├─► EPIC-006
           ├─► EPIC-007 ─────► EPIC-008
           ├─► EPIC-009
           ├─► EPIC-010
           └─► EPIC-011 ──────► EPIC-004
```

## Эпики Фаз 1–5

Появятся после гейтов G0 и G1: их состав зависит от результатов Фазы 0 и от
выбранного стека. Создавать их сейчас — планировать вслепую.

Исключение — [EPIC-005](EPIC-005-data-migration.md): он описан заранее, потому
что его подготовка (правила преобразования) начинается уже в Фазе 0, на
результатах EPIC-003.

## Что наполняют эпики

Работы Фазы 0 наполняют **обе** половины плана — спецификации продукта и карты
перехода:

| Эпик | Наполняет продукт | Наполняет переход |
|---|---|---|
| [EPIC-002](EPIC-002-contract-inventory.md) | [product/05-api.md](../product/05-api.md) — реестр эндпойнтов | [transition/03-api-mapping.md](../transition/03-api-mapping.md) — карта эндпойнтов |
| [EPIC-003](EPIC-003-schema-inventory.md) | [product/03-database.md](../product/03-database.md) — реестр таблиц | [transition/01-database-mapping.md](../transition/01-database-mapping.md) — карта таблиц |
| [EPIC-007](EPIC-007-reports-inventory.md) | страницы типа R в [product/06-frontend.md](../product/06-frontend.md) | решения «не переносим» по отчётам |
| [EPIC-011](EPIC-011-scenario-registry.md) | [product/06-frontend.md](../product/06-frontend.md) — реестр страниц | [transition/04-frontend-mapping.md](../transition/04-frontend-mapping.md) — карта страниц |
| [EPIC-006](EPIC-006-permissions-inventory.md) | права в спецификациях доменов | соответствие старых и новых прав |

Разбор классов ([transition/02-backend-mapping.md](../transition/02-backend-mapping.md))
выполняется внутри EPIC-002 и EPIC-003: границы модулей определяются составом
эндпойнтов и таблиц.

Образец результата — домен D1:
[спецификация](../product/spec/D1-reference.md) и
[карта](../transition/map/D1-reference.md).

## Правила

1. **Идентификаторы не переиспользуются.** Отменённый эпик остаётся с пометкой.
2. **У каждого эпика есть владелец** — человек, не роль.
3. **Задача с критериями приёмки** — иначе непонятно, когда она закрыта.
4. **Эпик закрыт, когда закрыты все его задачи** и достигнут результат из
   описания, а не когда «в основном сделано».
5. Изменения — через PR ([CONTRIBUTING.md](../CONTRIBUTING.md)).

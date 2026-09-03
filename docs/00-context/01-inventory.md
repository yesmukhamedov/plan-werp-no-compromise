---
id: CTX-01
title: Инвентаризация текущей системы
status: actual
measured_at: 2026-09-03
---

# Инвентаризация текущей системы

Все числа получены измерением рабочих копий репозиториев на дату `measured_at`.
Это опорная точка: план оценивается относительно неё, и при расхождении
пересчитываются оценки в [transition/10-estimates.md](../../transition/10-estimates.md).

Метод измерения зафиксирован в [приложении](#приложение-как-измерялось), чтобы
цифры можно было воспроизвести и обновить.

## 1. Сводка по репозиториям

| Репозиторий | Роль | Стек | Файлов | Строк | Тестов | В проде |
|---|---|---|---:|---:|---:|---|
| `werp_jsf` | Легаси-монолит | JSF 2.2.8 + PrimeFaces 5.1, Hibernate 3.6.7, Spring 3.x, MySQL | 1 223 java + 472 xhtml | 233 913 | JUnit 3.8.1 (декларация) | **да** |
| `werp_java_back_v2` | Основной бэкенд | Spring Boot 2.0.0, Java 11, Oracle, Gradle | 3 597 | 354 761 | **4 файла** | да |
| `werp_react_front` | Фронтенд | React 16.11, Redux 3, CRA 3.4, JavaScript | 2 092 | 369 214 | 1 заглушка | да |
| `werp_crm` | CRM (вторая реализация) | Spring Boot 2.4.4, PostgreSQL, Flyway | 320 | 19 584 | есть | да |
| `werp_call_center` | Колл-центр | Spring Boot 2.4.5, PostgreSQL, Flyway | 217 | 8 969 | есть | да |
| `bridge` | Внешний шлюз | Go 1.22, stdlib, 0 зависимостей | 27 | 3 769 | 8 файлов | внедряется |
| `target-bridge` | Легаси-шлюз (Laravel 8) | PHP | — | — | — | выводится |

**Итого прикладного кода к замещению: ~990 тыс. строк** (без `bridge`, который
уже переписан и остаётся).

## 2. `werp_java_back_v2` — основной бэкенд

Gradle multi-project, `rootProject.name = 'werp'`, group `kz.aura.werp`, версия
`0.0.1` у всех модулей одновременно.

### 2.1. Модули

| Модуль | Артефакт | Файлов | Строк | Назначение |
|---|---|---:|---:|---|
| `core` | `werp-core` | 2 225 | 230 446 | основной монолит: 14 предметных областей |
| `service` | `werp-service` | 715 | 85 642 | сервисное обслуживание + частичное дублирование accounting |
| `crm` | `werp-crm` | 327 | 20 257 | CRM на Oracle (дублирует репозиторий `werp_crm` на PostgreSQL) |
| `main-module` | `werp-main-module` | 223 | 11 739 | общая библиотека: права, аудит, базовые сущности |
| `util` | `werp-utils` | 70 | 4 020 | утилиты; собирается под Java 8, остальное под 11 |
| `scheduler` | `werp-scheduler` | 23 | 1 625 | фоновые задачи |
| `auth-server` | `werp-auth-server` | 14 | 1 032 | OAuth2-сервер выдачи токенов |

Из семи модулей в CI собирается и деплоится **один** (`service`) — остальные
разворачиваются вручную.

### 2.2. Предметные области внутри `core`

| Область | Файлов | Строк | Что это |
|---|---:|---:|---|
| `accounting` | 292 | 62 776 | учёт, финансы, расчёт зарплаты |
| `hr` | 321 | 34 988 | персонал, штат, оклады, обучение |
| `marketing` | 272 | 34 228 | договоры, прайс-листы, продажи |
| `logistics` | 418 | 29 018 | склад, накладные, материалы, подотчёт |
| `dit` | 162 | 13 255 | внутренние задачи, сообщения, SMS, ABAC |
| `general` | 187 | 12 141 | платформа: авторизация, меню, экспорт, вложения |
| `service` | 71 | 10 970 | сервисное обслуживание (дублируется отдельным модулем `service`) |
| `reference` | 176 | 10 670 | справочники |
| `crm` | 102 | 8 905 | CRM и колл-центр (дублируется модулем `crm` и двумя репозиториями) |
| `mreference` | 78 | 4 140 | вторая реализация справочников: адреса, клиенты, телефоны |
| `aes` | 40 | 3 909 | учётный модуль (назначение требует уточнения — см. OQ-004) |
| `documents` | 37 | 2 584 | внутренний документооборот, маршруты согласования |
| `newdev` | 53 | 1 869 | заявки (назначение требует уточнения — см. OQ-004) |
| `law_department` | 15 | 989 | юридический отдел: суды, взыскания |

### 2.3. Поверхность API и модель

| Метрика | Значение |
|---|---:|
| HTTP-эндпойнтов (`@Get/Post/Put/Delete/PatchMapping`) | **1 286** |
| — GET | 708 |
| — POST | 336 |
| — PUT | 138 |
| — DELETE | 91 |
| — PATCH | 13 |
| `@RequestMapping` (в т. ч. на классах) | 410 |
| Контроллеров | 243 |
| `@Service` | 418 |
| JPA-сущностей (`@Entity`) | **523** |
| Spring Data репозиториев | 165 |
| `@Query` | 451 |
| из них `nativeQuery = true` | 43 |
| `EntityManager.createQuery` | 837 |
| `EntityManager.createNativeQuery` | 289 |
| Использований `JdbcTemplate` | 20 |
| `@Transactional` | 1 084 |

Три конкурирующих способа доступа к данным (Spring Data, JPQL через
`EntityManager`, нативный SQL и `JdbcTemplate`) сосуществуют в одном модуле.

### 2.4. Зависимости

- Spring Boot **2.0.0.RELEASE** — первый релиз ветки 2.0, вышел в феврале 2018,
  вне поддержки с 2019 года.
- Spring Cloud **Finchley.M9** — *milestone*, а не релиз.
- Hibernate 5.4.31 поднят вручную поверх версии, управляемой Boot 2.0;
  зависимости `spring-cloud-starter-oauth2:2.2.4` и
  `spring-cloud-starter-bootstrap:3.0.1` относятся к другим поколениям Boot.
- Oracle JDBC — `ojdbc6-11.2.0.3` из локальной папки `libs/` через `flatDir`.
  Собрать проект без этого файла нельзя.
- springfox-swagger 2.9.2, Guava 20.0, jjwt 0.7.0, ModelMapper, Redisson 3.12.4.
- Joda-Time используется параллельно с `java.time`.
- Модуль `util` компилируется под `sourceCompatibility = 1.8`, остальные — под 11.

## 3. `werp_react_front` — фронтенд

| Метрика | Значение |
|---|---:|
| Файлов `.js`/`.jsx` | 2 092 |
| Строк | 369 214 |
| Файлов TypeScript | **0** |
| Классовых компонентов | 273 |
| Использований `useState` | 2 185 |
| Устаревших методов жизненного цикла (`componentWill*`) | 189 |
| Ссылок на легаси-JSF из React | 33 |
| Языков локализации | 3 (ru / en / tr) |
| Строк в `routes/routes.js` | 2 695 |

Разделы по числу строк: `service` 55 884, `hr` 41 945, `logistics` 39 406,
`finance` 39 309, `crm2021` 35 830, `dit` 30 626, `callcenter` 28 160,
`marketing` 26 673, `crm` 20 068, `reference` 8 391, `accounting` 7 569,
`edu` 7 024, `aes` 6 791, `utils` 4 789, `components` 3 581, `lawyer` 3 437,
`admin` 2 606, прочее — меньше.

`crm` и `crm2021` — две параллельные реализации одного раздела; `finance` и
`accounting` разделены не так, как на бэкенде.

### Стек фронтенда

- React 16.11 (актуальная ветка — 19), `react-scripts` 3.4.0 (Create React App
  снят с поддержки), Babel-конфигурация от `babel-preset-react-app` 3.1.1.
- Redux 3.7 + `react-redux` 5.1 + `redux-form` 7.2 — все три поколения назад.
- `react-router` 4.
- Три библиотеки деревьев: `react-sortable-tree`, `react-treebeard`, `react-treeview`.
- Три способа выгрузки в Excel: `xlsx`, `react-export-excel`, `react-data-export`.
- Два стека графиков: `chart.js` + `react-chartjs-2` и `recharts`.
- Две библиотеки дат: `moment` и `date-fns`.
- Две библиотеки произвольной точности: `bigdecimal` и `bignumber.js`.
- `faker` и `@faker-js/faker` — генераторы тестовых данных — в
  **производственных** зависимостях.
- `axios` 0.21, `react-table` 6.10.3, `semantic-ui-react` 0.72 — вне поддержки.

## 4. Отдельные сервисы

`werp_crm` (Spring Boot 2.4.4) и `werp_call_center` (Spring Boot 2.4.5) —
попытка выделения доменов, начатая и не доведённая. Обе на PostgreSQL с Flyway,
структура пакетов заметно чище (`domain/model`, `domain/repository`,
`domain/spec`, `converter`, `dto/{form,grid,detail,report,search}`), тесты есть.

При этом `werp_crm` (320 файлов) сосуществует с модулем `crm` внутри
`werp_java_back_v2` (327 файлов) — **CRM реализован дважды, на двух разных
СУБД**. Какая из реализаций является источником истины для каких сценариев —
[OQ-002](../../transition/12-open-questions.md).

В `werp_call_center` в репозиторий закоммичены журналы приложения и аварийные
дампы JVM (`hs_err_pid*.log`).

## 5. `bridge` — эталон

Внешний шлюз, переписанный с Laravel-версии на Go (stdlib, ноль внешних
зависимостей, 3 769 строк, 8 тестовых файлов). Единственная часть системы, уже
приведённая к целевому качеству: явный allowlist маршрутов, один деплой = одно
окружение, доверие заголовкам только от доверенных прокси, дублирующие тесты,
фиксирующие легаси-контракты 1:1.

**`bridge` из области переписывания исключён** и остаётся как есть. Его README —
образец того, как должна выглядеть документация модуля нового WERP (см.
[01-principles/03-engineering-standards.md](../01-principles/03-engineering-standards.md)).

## 6. Инфраструктура

- Kubernetes, самоуправляемый GitHub Actions runner, реестр образов в Docker Hub.
- Три контура: dev, stage, prod. Адреса контуров **захардкожены в `package.json`**
  фронтенда (`build:dev` / `build:stage` / `build:prod`) и попадают в собранный
  бандл.
- Базовые образы: `openjdk:11` (архивный, обновления не выпускаются) в четырёх
  из пяти Dockerfile; `eclipse-temurin:11-jre` в одном.
- Сборка в CI выполняется с `-x test`.
- Рядом лежит неработающий `bitbucket-pipelines.yml` с образом `maven:3.3.9-jdk-8`
  — артефакт эпохи, когда проект собирался Maven.

## Приложение: как измерялось

```sh
# файлы и строки по модулю
find <module> -name '*.java' | wc -l
find <module> -name '*.java' -exec cat {} + | wc -l

# эндпойнты
grep -rE '@(Get|Post|Put|Delete|Patch)Mapping' --include=*.java . | wc -l

# сущности, сервисы, репозитории
grep -rl '@Entity' --include=*.java . | wc -l
grep -rl '@Service' --include=*.java . | wc -l
grep -rl 'extends JpaRepository\|extends CrudRepository' --include=*.java . | wc -l
```

Полный скрипт пересчёта — [tools/measure.sh](../../tools/measure.sh).

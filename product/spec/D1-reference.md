---
id: PROD-SPEC-D1
title: D1 Справочники — полная спецификация
status: спроектирован
domain: D1
owner: не назначен
---

# D1. Справочники

Эталонная спецификация: задаёт обязательную глубину для остальных доменов
([spec/README.md](README.md#d1--эталон)).

Схема БД: `reference` · Модуль: `reference` · API: `/api/v1/reference` ·
Раздел интерфейса: `pages/reference`

---

## Назначение и границы

Справочные данные, общие для всей системы: организационная структура, география,
валюты, номенклатура, типовые перечисления.

**Входит:** компании, филиалы, склады, страны, регионы, города, валюты, курсы
валют, единицы измерения, категории и позиции номенклатуры, типовые причины,
должности, направления деятельности.

**Не входит:**

| Что | Где | Почему не здесь |
|---|---|---|
| Клиенты, адреса, телефоны | D2 Контрагенты | контрагент — не справочник, у него жизненный цикл |
| Сотрудники, штат | D3 Персонал | то же |
| Прайс-листы, условия договора | D4 Договоры | зависят от договора, меняются часто |
| Пользователи, роли, права | D0 Платформа | это доступ, не справочник |
| Остатки на складах | D7 Склад | склад — справочник, остаток — операционные данные |

**Ключевое свойство домена:** от него зависят все остальные, он не зависит ни
от одного (кроме платформы). Поэтому он проектируется и реализуется первым, и
поэтому его публичный интерфейс должен быть особенно узким — его будут
использовать двенадцать модулей.

## Модель

Пять агрегатов:

| Агрегат | Корень | Состав | Инварианты |
|---|---|---|---|
| Организация | `Company` | `Branch` (дерево), `Warehouse` | филиал принадлежит одной компании; дерево филиалов без циклов; у компании ровно один головной филиал |
| География | `Country` | `Region`, `City` | город принадлежит региону, регион — стране; код страны уникален |
| Валюты | `Currency` | `ExchangeRate` | код валюты уникален; курс на дату уникален для пары валют |
| Номенклатура | `ProductCategory` | `Product`, `UnitOfMeasure` | позиция принадлежит одной категории; артикул уникален в компании |
| Перечисления | `ReferenceList` | `ReferenceItem` | код элемента уникален внутри списка |

Агрегат — граница транзакции и граница загрузки. Ссылка между агрегатами — по
идентификатору.

### Общий механизм перечислений

Мелкие справочники (причины увольнения, типы адресов, статусы проблем, виды
операций) **не получают собственных таблиц**. Они хранятся как элементы
поименованных списков в двух таблицах `reference_list` / `reference_item`.

Причина: каждый такой справочник — это 3–5 колонок и один экран. Пятнадцать
отдельных таблиц с пятнадцатью контроллерами и пятнадцатью экранами — это
пятнадцатикратное дублирование одного и того же кода.

Справочник получает **собственную** таблицу, если выполнено хотя бы одно:
у него больше трёх содержательных атрибутов; на него ссылаются с ограничением
целостности; у него есть собственные бизнес-правила; он редактируется
отдельной ролью.

---

## Таблицы

Схема `reference`. Все таблицы имеют
[обязательные столбцы](../03-database.md#обязательные-столбцы) — `id`,
`created_at`, `created_by`, `updated_at`, `updated_by`, `version` — они не
повторяются в перечнях ниже.

### `company` — компания

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `code` | `text` | нет | `ck` длина 1–10 | краткий код компании |
| `name` | `text` | нет | `ck` длина 1–255 | наименование |
| `full_name` | `text` | да | | полное юридическое наименование |
| `tax_number` | `text` | да | `ck` длина 1–20 | налоговый номер |
| `country_id` | `uuid` | нет | → `country.id` | страна регистрации |
| `default_currency_id` | `uuid` | нет | → `currency.id` | валюта учёта |
| `is_active` | `boolean` | нет | по умолчанию `true` | действующая |

Индексы: `ux_company__code`, `ix_company__country_id`.

### `branch` — филиал

Дерево подразделений компании.

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `company_id` | `uuid` | нет | → `company.id` | владелец |
| `parent_id` | `uuid` | да | → `branch.id` | родитель в дереве; `null` — корень |
| `code` | `text` | нет | `ck` длина 1–20 | код филиала |
| `name` | `text` | нет | | наименование |
| `kind` | `text` | нет | `ck IN (HEAD, REGION, BRANCH, POINT)` | уровень в структуре |
| `city_id` | `uuid` | да | → `city.id` | город расположения |
| `address_text` | `text` | да | | адрес одной строкой |
| `latitude` | `numeric(9,6)` | да | `ck` −90…90 | широта |
| `longitude` | `numeric(9,6)` | да | `ck` −180…180 | долгота |
| `is_active` | `boolean` | нет | по умолчанию `true` | действующий |
| `path` | `ltree` | нет | | материализованный путь для запросов по дереву |
| `depth` | `integer` | нет | `ck` ≥ 0 | глубина, денормализация от `path` |

Индексы: `ux_branch__company_id__code`, `ix_branch__parent_id`,
`ix_branch__path` (GiST), `ix_branch__city_id`,
`ix_branch__company_id` частичный `WHERE is_active`.

Ограничения: `ck_branch__no_self_parent` (`parent_id <> id`); отсутствие циклов
проверяется прикладным правилом `BranchTreeRule` — в БД это невыразимо.

> `path` и `depth` хранятся, потому что дерево филиалов читается почти на каждом
> экране системы (фильтр «по филиалу»), а рекурсивный запрос на каждом чтении
> измеримо дороже. Поддерживаются триггером и покрыты тестом.

### `warehouse` — склад

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `company_id` | `uuid` | нет | → `company.id` | владелец |
| `branch_id` | `uuid` | нет | → `branch.id` | привязка к филиалу |
| `code` | `text` | нет | `ck` длина 1–20 | код склада |
| `name` | `text` | нет | | наименование |
| `kind` | `text` | нет | `ck IN (MAIN, TRANSIT, SERVICE, RETURN)` | тип |
| `is_main` | `boolean` | нет | по умолчанию `false` | основной для филиала |
| `is_active` | `boolean` | нет | по умолчанию `true` | действующий |

Индексы: `ux_warehouse__company_id__code`, `ix_warehouse__branch_id`,
`ux_warehouse__branch_id__is_main` частичный `WHERE is_main` — гарантирует не
более одного основного склада на филиал.

### `country` — страна

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `code` | `text` | нет | `ck` длина 2, верхний регистр | ISO 3166-1 alpha-2 |
| `code3` | `text` | да | `ck` длина 3 | ISO 3166-1 alpha-3 |
| `currency_id` | `uuid` | да | → `currency.id` | валюта страны |
| `phone_prefix` | `text` | да | `ck` длина 1–6 | телефонный префикс |
| `phone_pattern` | `text` | да | | шаблон проверки номера |

Индексы: `ux_country__code`, `ux_country__code3`.

Наименования — в `country_name` (см. [локализацию](#локализация-справочников)).

### `region` — регион

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `country_id` | `uuid` | нет | → `country.id` | страна |
| `code` | `text` | да | | код региона |

Индексы: `ix_region__country_id`, `ux_region__country_id__code` частичный
`WHERE code IS NOT NULL`.

### `city` — город

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `region_id` | `uuid` | нет | → `region.id` | регион |
| `code` | `text` | да | | код города |
| `phone_prefix` | `text` | да | | телефонный код |
| `timezone` | `text` | нет | по умолчанию `Asia/Almaty` | часовой пояс |

Индексы: `ix_city__region_id`.

> `country_id` в городе **отсутствует намеренно**: он выводится через регион.
> Денормализация здесь порождает возможность рассогласования, а выигрыш
> отсутствует — выборка городов всегда идёт по региону.

### `currency` — валюта

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `code` | `text` | нет | `ck` длина 3, верхний регистр | ISO 4217 |
| `numeric_code` | `text` | да | `ck` длина 3 | числовой код ISO |
| `symbol` | `text` | да | | символ |
| `minor_units` | `smallint` | нет | `ck` 0–4, по умолчанию 2 | знаков после запятой при отображении |

Индексы: `ux_currency__code`.

### `exchange_rate` — курс валюты

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `from_currency_id` | `uuid` | нет | → `currency.id` | из валюты |
| `to_currency_id` | `uuid` | нет | → `currency.id` | в валюту |
| `rate_date` | `date` | нет | | дата действия |
| `rate` | `numeric(19,8)` | нет | `ck` > 0 | курс |
| `source` | `text` | нет | `ck IN (NATIONAL_BANK, MANUAL, PARTNER)` | источник |

Индексы: `ux_exchange_rate__from__to__date`,
`ix_exchange_rate__rate_date`.

Ограничение: `ck_exchange_rate__different_currencies`
(`from_currency_id <> to_currency_id`).

> Курс — **исторические данные, не справочник**: строки не изменяются и не
> удаляются. Пересчёт задним числом меняет финансовую отчётность, поэтому
> исправление оформляется новой строкой с другим `source`, а не правкой
> существующей.

### `unit_of_measure` — единица измерения

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `code` | `text` | нет | `ck` длина 1–10 | код |
| `precision` | `smallint` | нет | `ck` 0–6, по умолчанию 0 | допустимых знаков после запятой |

Индексы: `ux_unit_of_measure__code`.

### `product_category` — категория номенклатуры

Дерево категорий.

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `parent_id` | `uuid` | да | → `product_category.id` | родитель |
| `code` | `text` | нет | | код категории |
| `path` | `ltree` | нет | | материализованный путь |
| `is_active` | `boolean` | нет | по умолчанию `true` | действующая |

Индексы: `ux_product_category__code`, `ix_product_category__parent_id`,
`ix_product_category__path` (GiST).

### `product` — позиция номенклатуры

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `company_id` | `uuid` | нет | → `company.id` | владелец |
| `category_id` | `uuid` | нет | → `product_category.id` | категория |
| `article` | `text` | нет | `ck` длина 1–40 | артикул |
| `name` | `text` | нет | | наименование |
| `unit_id` | `uuid` | нет | → `unit_of_measure.id` | базовая единица |
| `barcode` | `text` | да | `ck` длина 8–14 | штрихкод |
| `is_serial_tracked` | `boolean` | нет | по умолчанию `false` | учёт по серийным номерам |
| `warranty_months` | `smallint` | да | `ck` ≥ 0 | гарантия |
| `is_active` | `boolean` | нет | по умолчанию `true` | действующая |

Индексы: `ux_product__company_id__article`, `ix_product__category_id`,
`ix_product__barcode` частичный `WHERE barcode IS NOT NULL`,
`ix_product__name_trgm` (GIN, триграммы) — для поиска по части наименования.

### `reference_list` / `reference_item` — типовые перечисления

`reference_list`:

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `code` | `text` | нет | `ck` `^[A-Z_]+$` | код списка, например `LEAVE_REASON` |
| `is_system` | `boolean` | нет | по умолчанию `false` | системный — не редактируется из интерфейса |

Индексы: `ux_reference_list__code`.

`reference_item`:

| Колонка | Тип | Null | Ограничения | Смысл |
|---|---|---|---|---|
| `list_id` | `uuid` | нет | → `reference_list.id` | список |
| `code` | `text` | нет | | код элемента |
| `sort_order` | `integer` | нет | по умолчанию 0 | порядок отображения |
| `is_active` | `boolean` | нет | по умолчанию `true` | действующий |
| `attributes` | `jsonb` | да | | дополнительные атрибуты списка |

Индексы: `ux_reference_item__list_id__code`,
`ix_reference_item__list_id` частичный `WHERE is_active`.

> `attributes` — единственное применение `jsonb` в домене, и оно обосновано:
> набор атрибутов различается от списка к списку и не участвует в выборках.
> Как только по атрибуту требуется фильтровать — список получает собственную
> таблицу.

### Локализация справочников

Переводимые наименования вынесены в парные таблицы. Добавление языка не требует
миграции схемы ([03-database.md](../03-database.md#локализация-в-данных)).

| Таблица | Колонки |
|---|---|
| `country_name` | `country_id` → `country.id`, `locale`, `name` |
| `region_name` | `region_id`, `locale`, `name` |
| `city_name` | `city_id`, `locale`, `name` |
| `currency_name` | `currency_id`, `locale`, `name` |
| `unit_of_measure_name` | `unit_id`, `locale`, `name` |
| `product_category_name` | `category_id`, `locale`, `name` |
| `reference_item_name` | `item_id`, `locale`, `name` |

У каждой: `ux_<таблица>__<родитель>_id__locale`,
`ck` на `locale IN (ru, en, tr)`.

Наименования компаний, филиалов, складов и позиций номенклатуры **не
переводятся** — это собственные имена, они одинаковы на всех языках.

### Сводка

| Таблица | Оценка строк | Изменяемость |
|---|---:|---|
| `company` | десятки | редко |
| `branch` | сотни | редко |
| `warehouse` | сотни | редко |
| `country` | ~250 | почти никогда |
| `region` | тысячи | почти никогда |
| `city` | десятки тысяч | редко |
| `currency` | десятки | почти никогда |
| `exchange_rate` | сотни тысяч, растёт | только вставка |
| `unit_of_measure` | десятки | почти никогда |
| `product_category` | сотни | редко |
| `product` | десятки тысяч | регулярно |
| `reference_list` | десятки | почти никогда |
| `reference_item` | тысячи | регулярно |
| таблицы наименований (7) | ×3 к родителю | вместе с родителем |

Итого **20 таблиц**. Кэшируются на уровне приложения все, кроме `exchange_rate`
и `product`; инвалидация — по событию изменения.

## Справочные данные

Загружаются миграцией схемы, версионируются вместе с ней, в интерфейсе не
редактируются:

- `country`, `region` — по ISO 3166 с наименованиями на трёх языках;
- `currency` — по ISO 4217;
- `unit_of_measure` — базовый набор;
- `reference_list` — системные списки с `is_system = true`.

---

## Классы

Модуль `reference`. Структура — [04-backend.md](../04-backend.md#структура-модуля).

### `api/` — публичный интерфейс

Всё, что видят другие двенадцать модулей. Намеренно узкий.

| Класс | Операции |
|---|---|
| `ReferenceFacade` | `getCompany(id)`, `getBranch(id)`, `getBranchSubtree(id)`, `getWarehouse(id)`, `getProduct(id)`, `getCurrency(id)`, `getRate(from, to, date)`, `getItem(list, code)`, `resolveNames(ids, locale)` |
| `ReferenceQuery` | пакетное чтение: `getCompanies(ids)`, `getBranches(ids)`, `getProducts(ids)` — чтобы вызывающий не делал N обращений |
| dto | `CompanyDto`, `BranchDto`, `BranchTreeDto`, `WarehouseDto`, `CountryDto`, `CityDto`, `CurrencyDto`, `ExchangeRateDto`, `ProductDto`, `ProductCategoryDto`, `UnitOfMeasureDto`, `ReferenceItemDto` |
| events | `CompanyChanged`, `BranchChanged`, `BranchDeactivated`, `WarehouseChanged`, `ProductChanged`, `ProductDeactivated`, `ExchangeRateAdded`, `ReferenceItemChanged` |

`resolveNames` существует, чтобы другие домены не тянули справочник целиком
ради отображения наименования рядом с идентификатором.

События деактивации отдельны от событий изменения: деактивация филиала или
позиции затрагивает открытые документы в других доменах, и они должны на неё
реагировать.

### `domain/` — бизнес-логика

| Класс | Тип | Ответственность |
|---|---|---|
| `Company` | сущность | компания, её инварианты |
| `Branch` | сущность | филиал, положение в дереве |
| `BranchTree` | объект-значение | операции над деревом: поддерево, предки, путь |
| `Warehouse` | сущность | склад |
| `Country`, `Region`, `City` | сущности | география |
| `Currency` | сущность | валюта |
| `ExchangeRate` | сущность | курс на дату, неизменяемый |
| `Product`, `ProductCategory` | сущности | номенклатура |
| `UnitOfMeasure` | сущность | единица измерения |
| `ReferenceList`, `ReferenceItem` | сущности | перечисления |
| `LocalizedName` | объект-значение | наименование на языке |
| `BranchTreeRule` | правило | отсутствие циклов, корректность уровней |
| `SingleMainWarehouseRule` | правило | один основной склад на филиал |
| `RateChronologyRule` | правило | корректность даты курса |
| `DeactivationRule` | правило | что нельзя деактивировать при наличии зависимых |
| `BranchService` | доменный сервис | перемещение узла дерева, пересчёт `path` |
| `ExchangeRateService` | доменный сервис | подбор курса на дату; при отсутствии — ближайший предшествующий |

### `application/` — сценарии

По обработчику на сценарий; каждый — граница транзакции.

`CreateCompanyHandler`, `UpdateCompanyHandler`, `CreateBranchHandler`,
`UpdateBranchHandler`, `MoveBranchHandler`, `DeactivateBranchHandler`,
`CreateWarehouseHandler`, `UpdateWarehouseHandler`, `CreateProductHandler`,
`UpdateProductHandler`, `DeactivateProductHandler`, `ImportProductsHandler`,
`CreateProductCategoryHandler`, `MoveProductCategoryHandler`,
`AddExchangeRateHandler`, `ImportExchangeRatesHandler`,
`CreateReferenceItemHandler`, `UpdateReferenceItemHandler`,
`ReorderReferenceItemsHandler`.

Запросы чтения: `BranchTreeQuery`, `ProductSearchQuery`, `CityLookupQuery`,
`ExchangeRateQuery` — отдельно от обработчиков команд, без транзакции записи.

### `adapter/web/` — контроллеры

Генерируются из спецификации; логики не содержат.

`CompanyController`, `BranchController`, `WarehouseController`,
`CountryController`, `RegionController`, `CityController`,
`CurrencyController`, `ExchangeRateController`, `ProductController`,
`ProductCategoryController`, `UnitOfMeasureController`,
`ReferenceItemController`.

**Двенадцать контроллеров, по одному на ресурс.** Ни один не превышает 200
строк, ни один не обращается к чужому домену.

### `adapter/persistence/` — хранилище

`CompanyRepository`, `BranchRepository`, `WarehouseRepository`,
`CountryRepository`, `RegionRepository`, `CityRepository`,
`CurrencyRepository`, `ExchangeRateRepository`, `ProductRepository`,
`ProductCategoryRepository`, `UnitOfMeasureRepository`,
`ReferenceListRepository`, `LocalizedNameRepository`.

Плюс `ReferenceCache` — кэш редко меняющихся справочников с инвалидацией по
доменным событиям.

### Оценка объёма

~90 классов: 12 контроллеров, 13 репозиториев, 19 обработчиков, 4 запроса
чтения, ~14 сущностей и объектов-значений, 4 правила, 2 доменных сервиса,
2 фасада, ~12 DTO, 8 событий, преобразователи.

---

## Эндпойнты

`/api/v1/reference`. Полное описание — в спецификации OpenAPI; здесь состав и
права.

### Компании

| Метод | Путь | Право | Примечание |
|---|---|---|---|
| GET | `/companies` | `reference.company.read` | список, пагинация |
| GET | `/companies/{id}` | `reference.company.read` | |
| POST | `/companies` | `reference.company.write` | |
| PUT | `/companies/{id}` | `reference.company.write` | |
| POST | `/companies/{id}/deactivation` | `reference.company.write` | вместо DELETE |

### Филиалы

| Метод | Путь | Право | Примечание |
|---|---|---|---|
| GET | `/branches` | `reference.branch.read` | список; фильтры `companyId`, `kind`, `cityId`, `isActive` |
| GET | `/branches/tree` | `reference.branch.read` | дерево; параметр `rootId` |
| GET | `/branches/{id}` | `reference.branch.read` | |
| POST | `/branches` | `reference.branch.write` | |
| PUT | `/branches/{id}` | `reference.branch.write` | |
| POST | `/branches/{id}/move` | `reference.branch.write` | смена родителя |
| POST | `/branches/{id}/deactivation` | `reference.branch.write` | |

### Склады

| Метод | Путь | Право |
|---|---|---|
| GET | `/warehouses` | `reference.warehouse.read` |
| GET | `/warehouses/{id}` | `reference.warehouse.read` |
| POST | `/warehouses` | `reference.warehouse.write` |
| PUT | `/warehouses/{id}` | `reference.warehouse.write` |
| POST | `/warehouses/{id}/deactivation` | `reference.warehouse.write` |

### География

| Метод | Путь | Право |
|---|---|---|
| GET | `/countries` | `reference.geo.read` |
| GET | `/countries/{id}` | `reference.geo.read` |
| GET | `/regions` | `reference.geo.read` |
| GET | `/cities` | `reference.geo.read` |
| GET | `/cities/{id}` | `reference.geo.read` |
| POST / PUT | `/countries`, `/regions`, `/cities` | `reference.geo.write` |

Списки регионов и городов фильтруются через `countryId` / `regionId` —
**отдельных путей вида `/regions/{countryId}` не существует**: фильтр не меняет
ресурс.

### Валюты и курсы

| Метод | Путь | Право |
|---|---|---|
| GET | `/currencies` | `reference.currency.read` |
| GET | `/exchange-rates` | `reference.currency.read` |
| GET | `/exchange-rates/current` | `reference.currency.read` |
| POST | `/exchange-rates` | `reference.currency.write` |
| POST | `/exchange-rates/import` | `reference.currency.write` |

`POST /exchange-rates` не имеет парного PUT: курс неизменяем.

### Номенклатура

| Метод | Путь | Право |
|---|---|---|
| GET | `/products` | `reference.product.read` |
| GET | `/products/{id}` | `reference.product.read` |
| POST | `/products` | `reference.product.write` |
| PUT | `/products/{id}` | `reference.product.write` |
| POST | `/products/{id}/deactivation` | `reference.product.write` |
| POST | `/products/import` | `reference.product.import` |
| GET | `/product-categories` | `reference.product.read` |
| GET | `/product-categories/tree` | `reference.product.read` |
| POST / PUT | `/product-categories` | `reference.product.write` |
| GET | `/units` | `reference.unit.read` |
| POST / PUT | `/units` | `reference.unit.write` |

### Перечисления

| Метод | Путь | Право |
|---|---|---|
| GET | `/lists` | `reference.list.read` |
| GET | `/lists/{code}/items` | `reference.list.read` |
| POST | `/lists/{code}/items` | `reference.list.write` |
| PUT | `/lists/{code}/items/{id}` | `reference.list.write` |
| POST | `/lists/{code}/items/reorder` | `reference.list.write` |

**Итого 48 эндпойнтов на 12 ресурсов.**

### Коды ошибок домена

`reference.company.not_found`, `reference.company.code_taken`,
`reference.branch.not_found`, `reference.branch.cycle_detected`,
`reference.branch.has_active_children`, `reference.warehouse.main_already_exists`,
`reference.product.article_taken`, `reference.product.in_use`,
`reference.rate.not_found_for_date`, `reference.rate.same_currency`,
`reference.item.code_taken`, `reference.list.is_system`.

---

## Права

| Право | Что разрешает |
|---|---|
| `reference.company.read` / `.write` | компании |
| `reference.branch.read` / `.write` | филиалы |
| `reference.warehouse.read` / `.write` | склады |
| `reference.geo.read` / `.write` | география |
| `reference.currency.read` / `.write` | валюты и курсы |
| `reference.product.read` / `.write` / `.import` | номенклатура |
| `reference.unit.read` / `.write` | единицы измерения |
| `reference.list.read` / `.write` | перечисления |

**Ограничение по области данных:** пользователь видит компании и филиалы своей
области видимости. Применяется в `adapter/persistence`, а не в контроллере
([ADR-0006](../../docs/02-decisions/ADR-0006-auth-model.md)).

География, валюты и единицы измерения областью не ограничиваются — они общие.

---

## Страницы

`pages/reference`. Типы — [06-frontend.md](../06-frontend.md#пять-типов-страниц).

| Код | Маршрут | Тип | Право | Назначение |
|---|---|---|---|---|
| `REF-COM-L` | `/reference/companies` | L | `reference.company.read` | список компаний |
| `REF-COM-F` | `/reference/companies/:id` | F | `reference.company.write` | карточка-форма компании |
| `REF-BRN-T` | `/reference/branches` | L | `reference.branch.read` | дерево филиалов с боковой панелью |
| `REF-BRN-F` | `/reference/branches/:id` | F | `reference.branch.write` | форма филиала |
| `REF-WHS-L` | `/reference/warehouses` | L | `reference.warehouse.read` | список складов |
| `REF-WHS-F` | `/reference/warehouses/:id` | F | `reference.warehouse.write` | форма склада |
| `REF-GEO-L` | `/reference/geo` | L | `reference.geo.read` | география: страны → регионы → города |
| `REF-CUR-L` | `/reference/currencies` | L | `reference.currency.read` | валюты |
| `REF-RAT-L` | `/reference/exchange-rates` | L | `reference.currency.read` | курсы с фильтром по датам |
| `REF-PRD-L` | `/reference/products` | L | `reference.product.read` | номенклатура: дерево категорий + таблица |
| `REF-PRD-F` | `/reference/products/:id` | F | `reference.product.write` | форма позиции |
| `REF-PRD-I` | `/reference/products/import` | F | `reference.product.import` | загрузка номенклатуры файлом |
| `REF-UOM-L` | `/reference/units` | L | `reference.unit.read` | единицы измерения |
| `REF-LST-L` | `/reference/lists/:code?` | L | `reference.list.read` | **все** типовые перечисления, один экран |

**14 страниц.** Последняя обслуживает все перечисления сразу: слева список
справочников, справа элементы выбранного. Пятнадцать отдельных экранов для
пятнадцати мелких справочников не создаются — это и есть практический результат
[общего механизма перечислений](#общий-механизм-перечислений).

### Компоненты домена

Помимо дизайн-системы, домен добавляет три переиспользуемых компонента —
их используют **все остальные** разделы приложения:

| Компонент | Где используется | Поведение |
|---|---|---|
| `BranchLookup` | почти каждый фильтр в системе | дерево с поиском, множественный выбор, «включая подчинённые» |
| `ProductLookup` | договоры, склад, сервис | поиск по артикулу, наименованию, штрихкоду; ленивая загрузка |
| `CurrencyAmountInput` | везде, где вводится сумма | сумма + валюта, точность по валюте |

Они живут в `features/`, а не в `pages/reference`: страница ими не владеет.

### Состояния страниц

Каждая страница обязана определять: загрузка (`Skeleton`), пусто
(`EmptyState` с подсказкой), ошибка (`ErrorState` с кодом и `traceId`), нет
права (`PermissionGate`).

---

## Аудит

Решение владельца домена — что именно аудируется
([03-database.md](../03-database.md#аудит)):

| Таблица | Аудируется | Почему |
|---|---|---|
| `company` | все изменения | влияет на всю финансовую отчётность |
| `branch` | все изменения, особенно `parent_id` и `is_active` | перемещение узла меняет отчётность по подразделениям |
| `warehouse` | все изменения | влияет на складской учёт |
| `product` | изменения `article`, `unit_id`, `is_serial_tracked`, `is_active` | влияет на документы |
| `exchange_rate` | только вставка | строки неизменяемы |
| `reference_item` | изменения `code`, `is_active` | код используется в документах |
| `country`, `region`, `city`, `currency`, `unit_of_measure` | **не аудируются** | меняются раз в годы, изменения безобидны |

Наименования (`*_name`) не аудируются: правка перевода не меняет смысла данных.

---

## Открытые вопросы

| # | Вопрос | Влияет на |
|---|---|---|
| D1-Q1 | Нужен ли уровень «регион» в дереве филиалов как отдельный `kind`, или структура произвольной глубины? | `branch.kind`, `BranchTreeRule` |
| D1-Q2 | Откуда берутся курсы валют — автоматическая загрузка из внешнего источника или ручной ввод? | `exchange_rate.source`, `ImportExchangeRatesHandler` |
| D1-Q3 | Уникален ли артикул в пределах компании или всей системы? | `ux_product__company_id__article` |
| D1-Q4 | Какие из мелких справочников действительно требуют собственных таблиц? | состав `reference_list` |
| D1-Q5 | Нужен ли перевод наименований позиций номенклатуры? | `product_name` |

Вопросы закрываются владельцем домена до начала реализации (Фаза 1). Каждый
меняет схему, поэтому они закрываются **до** первой миграции, а не после.

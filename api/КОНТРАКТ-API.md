# REST API «Магазин косметики» — Практика 4

Адаптация учебного API «Библиотека» под индивидуальную предметную область.
Базовый адрес: `http://localhost:8080/api`. Node.js 18+, сторонних npm-пакетов нет.
Данные в памяти **сервера**, не клиента; перезапуск возвращает `seed.json`.
Авторизация и роли не реализуются на этом этапе; принудительные 401/403 доступны
для проверки преобразования ошибок. Сервер слушает только loopback 127.0.0.1.

## Ресурсы и операции

Одинаковый набор для `products`, `brands`, `categories`, `suppliers`, `customers`:

| Метод | Путь | Ответ |
|---|---|---|
| GET | `/{resource}` | 200 — страница списка |
| GET | `/{resource}/{id}` | 200 — запись, 404 — отсутствует |
| POST | `/{resource}` | 201 — новая запись с ID сервера |
| PUT | `/{resource}/{id}` | 200 — изменённая запись |
| DELETE | `/{resource}/{id}` | 204 — логическое удаление |
| DELETE | `/{resource}/{id}?hard=true` | 204 — физическое удаление |
| POST | `/{resource}/{id}/restore` | 200 — восстановленная запись |
| POST | `/{resource}/bulk-delete` | `{ "deleted": 2 }`, тело `{ "ids": [1,2] }` |
| GET | `/__health` | `{ "status":"ok", "service":"cosmetics", "storage":"memory" }` |

В отличие от исходного библиотечного контракта GET по ID возвращает и логически
удалённую запись — её карточка доступна из списка «Только удалённые».
Записи создаются без клиентского ID, `deletedAt` управляется сервером.
Групповое удаление проверяет все связи до изменения; при конфликте не удаляется ничего.

## Списки

Ответ: `{ "items": [], "page": 1, "size": 10, "total": 0, "totalPages": 1 }`.

Общие параметры: `search`, `sort=name,asc` (или `desc`), `page` (с 1), `size`
(по умолчанию 10, максимум 100), `includeDeleted=true` (все записи),
`onlyDeleted=true` (только удалённые; приоритет над includeDeleted).
Сайт предлагает размеры 10/25/50. Страница за концом списка корректируется сервером.

| Ресурс | Фильтры | Поля сортировки |
|---|---|---|
| products | categoryId, brandId, minPrice/maxPrice в рублях | name, price, stock, id |
| brands | filter — страна | name, country, foundedYear, id |
| categories | filter=used/unused | name, productCount, id |
| suppliers | filter — город | name, city, email, id |
| customers | filter=active/expired — срок карты | name, email, points, id |

Поиск, фильтрация, сортировка, подсчёт и выделение страницы выполняются сервером.
Для диагностики списка: `__delay=1500` (мс, максимум 10000), `__fail=500`
(любой код 400–599). Те же параметры в адресе Flutter-страницы передаются в API.

## Запись и чтение связей

POST/PUT товара:

```json
{
  "name": "Увлажняющий крем", "sku": "NEW-001", "priceKopecks": 189000,
  "stock": 24, "volume": "50 мл", "description": "Ежедневный уход",
  "brandId": 1, "supplierId": 1, "categoryIds": [1,3]
}
```

В ответе вместо `brandId`, `supplierId`, `categoryIds` возвращаются
`brand: {id,name}`, `supplier: {id,name}`, `categories: [{id,name}]`.
Модель Flutter разбирает обе формы. Цена — целое количество копеек.

Бренд: name, country, foundedYear, description.
Категория: name, description; при чтении добавляется вычисленное `productCount`.
Поставщик: name, city, email, phone, brandIds; при чтении вместо brandIds — brands.
Покупатель: name, email, phone, card: {number, points, issuedAt, expiresAt}.
ID вложенной карты сервер приравнивает к ID покупателя. Даты — ISO 8601.

## Ошибки и валидация

`{ "message": "Причина" }` для 400, 401, 403, 404, 409, 500.
422: `{ "message": "Ошибка валидации", "errors": { "sku": "Товар с таким артикулом уже существует" } }`.

Поля ошибок совпадают с ключами формы, включая `price`, `card.number`,
`card.points`, `card.issuedAt`, `card.expiresAt`.
Проверяются обязательность/длина, форматы, диапазоны чисел, даты, существование
действующих связей, совместимость бренда с поставщиком, уникальность артикула,
почты покупателя и номера карты без учёта регистра (включая удалённые записи).

409 запрещает удаление бренда, категории или поставщика, на которых ссылаются
товары (в том числе удалённые), и бренда, указанного у поставщика.
Сообщение содержит количество зависимых записей.

## CORS

Запуск: `node api/mock-server.js --port 8080 --origin http://localhost:5555`.
На всех ответах, включая ошибки: Access-Control-Allow-Origin с заданным origin,
Vary: Origin, Allow-Methods GET/POST/PUT/DELETE/OPTIONS,
Allow-Headers Content-Type/Authorization, Max-Age 600.
OPTIONS возвращает 204. JSON POST/PUT с Content-Type application/json разрешён.
Открывать клиент нужно именно на http://localhost:5555 — 127.0.0.1 является
другим origin. Защита браузера не отключается.

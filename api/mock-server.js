#!/usr/bin/env node
'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const {createAuth} = require('./auth');
const args = process.argv.slice(2);
const arg = (name, fallback) => args.includes('--' + name) ? args[args.indexOf('--' + name) + 1] : fallback;
const kinds = ['products', 'brands', 'categories', 'suppliers', 'customers'];
const fail = (status, message, errors) => { throw { status, message, ...(errors && { errors }) }; };
function createServer({ origin = 'http://localhost:5555', log = true, ttl = 900, sessionSeconds = 3600, now } = {}) {
  const auth = createAuth({ttl,sessionSeconds,now});
  const orders = []; let nextOrder = 1;
  const db = JSON.parse(fs.readFileSync(path.join(__dirname, 'seed.json'), 'utf8'));
  const seq = Object.fromEntries(kinds.map(k => [k, Math.max(0, ...db[k].map(e => e.id)) + 1]));
  const count = id => db.products.filter(p => !p.deletedAt && p.categoryIds.includes(id)).length;
  const linked = (k, id) => db[k].find(e => e.id === id);
  const expand = (k, e) => {
    const copy = structuredClone(e);
    const brief = (kind, id) => { const x = linked(kind, id); return x ? { id: x.id, name: x.name } : null; };
    if (k === 'products') {
      copy.brand = brief('brands', e.brandId); copy.supplier = brief('suppliers', e.supplierId);
      copy.categories = e.categoryIds.map(id => brief('categories', id));
      delete copy.brandId; delete copy.supplierId; delete copy.categoryIds;
    }
    if (k === 'suppliers') { copy.brands = e.brandIds.map(id => brief('brands', id)); delete copy.brandIds; }
    if (k === 'categories') copy.productCount = count(e.id);
    return copy;
  };
  function validate(k, input, id, deletedAt = null) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) fail(400, 'Ожидается JSON-объект');
    const e = { id, deletedAt }, errors = {};
    const text = (key, min = 2, max = 120, src = input, dest = e, label = key) => {
      const value = typeof src[key] === 'string' ? src[key].trim() : '';
      dest[key] = value;
      if (value.length < min || value.length > max) errors[label] = `Длина: от ${min} до ${max} символов`;
      return value;
    };
    const integer = (key, min, max, src = input, dest = e, label = key) => {
      dest[key] = src[key];
      if (!Number.isSafeInteger(src[key]) || src[key] < min || src[key] > max) errors[label] = `Введите целое число от ${min} до ${max}`;
    };
    const code = (key, src = input, dest = e, label = key) => {
      const value = text(key, 3, 32, src, dest, label);
      if (!/^[A-Za-zА-Яа-я0-9][A-Za-zА-Яа-я0-9_\-]{2,31}$/.test(value)) errors[label] = 'От 3 до 32 букв, цифр, дефисов или подчёркиваний';
    };
    const exists = (kind, id) => db[kind].some(x => x.id === id && !x.deletedAt);
    const many = (key, kind) => {
      const ids = input[key]; e[key] = Array.isArray(ids) ? [...new Set(ids)] : [];
      if (!e[key].length || e[key].some(id => !Number.isSafeInteger(id) || !exists(kind, id))) errors[key] = 'Выберите действующие записи';
    };
    text('name');
    if (k === 'products') {
      code('sku'); text('volume', 2, 40); text('description', 2, 1000);
      integer('priceKopecks', 1, 100000000, input, e, 'price'); integer('stock', 0, 100000);
      for (const [key, kind] of [['brandId','brands'], ['supplierId','suppliers']]) {
        e[key] = input[key]; if (!exists(kind, e[key])) errors[key] = 'Выберите действующую запись';
      }
      many('categoryIds', 'categories');
      const s = linked('suppliers', e.supplierId);
      if (s && !s.brandIds.includes(e.brandId)) errors.brandId = 'Этот бренд не поставляется выбранным поставщиком';
      if (db.products.some(x => x.id !== id && x.sku.toLowerCase() === e.sku.toLowerCase())) errors.sku = 'Товар с таким артикулом уже существует';
    }
    if (k === 'brands') { text('country', 2, 60); text('description', 2, 1000); integer('foundedYear', 1800, new Date().getFullYear()); }
    if (k === 'categories') text('description', 0, 1000);
    if (k === 'suppliers' || k === 'customers') {
      const email = text('email', 3, 254);
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) errors.email = 'Некорректный адрес почты';
      const phone = text('phone', 10, 40);
      if (!/^\+?[\d\s()\-]+$/.test(phone) || phone.replace(/\D/g, '').length < 10 || phone.replace(/\D/g, '').length > 15) errors.phone = 'Введите телефон: от 10 до 15 цифр';
    }
    if (k === 'suppliers') {
      text('city', 2, 80); many('brandIds', 'brands');
      const n = db.products.filter(p => p.supplierId === id && !e.brandIds.includes(p.brandId)).length;
      if (n) errors.brandIds = `Нельзя убрать бренд: связанных товаров — ${n}`;
    }
    if (k === 'customers') {
      const c = input.card && typeof input.card === 'object' ? input.card : {};
      e.card = { id };
      code('number', c, e.card, 'card.number'); integer('points', 0, 1000000, c, e.card, 'card.points');
      for (const key of ['issuedAt', 'expiresAt']) {
        e.card[key] = c[key];
        if (typeof c[key] !== 'string' || !/^\d{4}-\d{2}-\d{2}T/.test(c[key]) || !Number.isFinite(Date.parse(c[key]))) errors['card.' + key] = 'Выберите корректную дату';
      }
      if (Date.parse(c.issuedAt) > Date.now()) errors['card.issuedAt'] = 'Дата выдачи не позднее сегодня';
      if (Date.parse(c.expiresAt) <= Date.parse(c.issuedAt)) errors['card.expiresAt'] = 'Дата окончания должна быть позже даты выдачи';
      if (db.customers.some(x => x.id !== id && x.email.toLowerCase() === e.email.toLowerCase())) errors.email = 'Покупатель с такой почтой уже существует';
      if (db.customers.some(x => x.id !== id && x.card.number.toLowerCase() === e.card.number.toLowerCase())) errors['card.number'] = 'Карта с таким номером уже существует';
    }
    if (Object.keys(errors).length) fail(422, 'Ошибка валидации', errors);
    return e;
  }
  function checkDelete(k, id) {
    if(k==='products'&&orders.some(o=>o.productId===id&&['new','ready'].includes(o.status))) fail(409,'На товар есть незавершённые заказы');
    const n = db.products.filter(p => k === 'brands' ? p.brandId === id : k === 'suppliers' ? p.supplierId === id : k === 'categories' ? p.categoryIds.includes(id) : false).length;
    const s = k === 'brands' ? db.suppliers.filter(s => s.brandIds.includes(id)).length : 0;
    if (n || s) fail(409, `Нельзя удалить запись: связанных ${n ? 'товаров' : 'поставщиков'} — ${n || s}. Сначала измените или удалите связи.`);
  }
  function list(k, q) {
    const needle = (q.get('search') || '').trim().toLowerCase(), filter = q.get('filter');
    let rows = db[k].filter(e => {
      if (q.get('onlyDeleted') === 'true' ? !e.deletedAt : q.get('includeDeleted') !== 'true' && e.deletedAt) return false;
      const haystack = [e.name, e.sku, e.country, e.city, e.email, e.phone, e.card?.number, e.description].filter(Boolean).join(' ').toLowerCase();
      if (!haystack.includes(needle)) return false;
      if (k === 'products') {
        if (q.has('categoryId') && !e.categoryIds.includes(Number(q.get('categoryId')))) return false;
        if (q.has('brandId') && e.brandId !== Number(q.get('brandId'))) return false;
        if (q.has('minPrice') && e.priceKopecks < Number(q.get('minPrice')) * 100) return false;
        if (q.has('maxPrice') && e.priceKopecks > Number(q.get('maxPrice')) * 100) return false;
      }
      if (filter && k === 'brands' && e.country !== filter) return false;
      if (filter && k === 'suppliers' && e.city !== filter) return false;
      if (filter && k === 'categories' && (count(e.id) > 0) !== (filter === 'used')) return false;
      if (filter && k === 'customers' && (Date.parse(e.card.expiresAt) > Date.now()) !== (filter === 'active')) return false;
      return true;
    });
    const [field = 'name', direction = 'asc'] = (q.get('sort') || 'name,asc').split(',');
    const value = e => field === 'price' ? e.priceKopecks : field === 'points' ? e.card?.points : field === 'productCount' ? count(e.id) : e[field] ?? e.name;
    rows.sort((a,b) => { const x = value(a), y = value(b); return ((typeof x === 'number' && typeof y === 'number' ? x-y : String(x).localeCompare(String(y), 'ru')) || a.id-b.id) * (direction === 'desc' ? -1 : 1); });
    const positive = (key, fallback, max) => { const n = Number(q.get(key) || fallback); return Number.isSafeInteger(n) && n > 0 ? Math.min(n, max) : fallback; };
    const size = positive('size', 10, 100), total = rows.length, totalPages = Math.max(1, Math.ceil(total / size));
    const page = Math.min(positive('page', 1, Number.MAX_SAFE_INTEGER), totalPages);
    return { items: rows.slice((page-1)*size, page*size).map(e => expand(k,e)), page, size, total, totalPages };
  }
  return http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost'), q = url.searchParams;
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Max-Age', '600');
    const send = (status, body) => { if (res.destroyed) return; res.statusCode = status; res.setHeader('Content-Type','application/json; charset=utf-8'); res.end(body === undefined ? undefined : JSON.stringify(body)); };
    res.on('finish', () => { if (log) console.log(`${req.method} ${req.url} → ${res.statusCode}`); });
    try {
      if (req.method === 'OPTIONS') return send(204);
      if (url.pathname === '/api/__health' && req.method === 'GET') return send(200, { status: 'ok', service: 'cosmetics', storage: 'memory', auth: true });
      const delay = Math.min(10000, Math.max(0, Number(q.get('__delay')) || 0));
      if (delay) await new Promise(r => setTimeout(r, delay));
      if (res.destroyed) return;
      const failure = Number(q.get('__fail'));
      if (Number.isInteger(failure) && failure >= 400 && failure <= 599) fail(failure, `Вот пример ошибки ${failure}`);
      const parts = url.pathname.split('/').filter(Boolean), k = parts[1];

      let body;
      if (['POST','PUT'].includes(req.method)) {
        if (!req.headers['content-type']?.startsWith('application/json')) fail(415, 'Требуется Content-Type: application/json');
        let raw = '';
        for await (const chunk of req) { raw += chunk; if (Buffer.byteLength(raw) > 1048576) fail(413, 'Слишком большой запрос'); }
        try { body = raw ? JSON.parse(raw) : {}; } catch { fail(400, 'Некорректный JSON'); }
      }
      if (body !== undefined && (!body || typeof body !== 'object' || Array.isArray(body))) fail(400,'Ожидается JSON-объект');
      if (parts[0] !== 'api') fail(404,'Адрес не найден');
      if (k === 'auth' && parts.length === 3) {
        const result=auth.handle(parts[2],req.method,body||{},req);return send(result.status,result.data);
      }
      const {user} = auth.authenticate(req);
      if(k==='admin') {
        auth.requireRole(user,'admin');
        if(req.method==='GET' && url.pathname==='/api/admin/users') return send(200,{items:auth.listUsers()});
        if(req.method==='PUT' && /^\/api\/admin\/users\/\d+\/role$/.test(url.pathname)) return send(200,auth.changeRole(user,Number(parts[3]),body.role));
        if(req.method==='GET' && url.pathname==='/api/admin/stats') return send(200,{products:db.products.filter(p=>!p.deletedAt).length,customers:db.customers.filter(c=>!c.deletedAt).length,users:auth.listUsers().length,orders:orders.length});
        fail(404,'Адрес не найден');
      }
      if(k==='account') {
        auth.requireRole(user,'customer');
        if(req.method==='GET' && parts.length===2) return send(200,{user:auth.publicUser(user),orders:orders.filter(o=>o.userId===user.id).length});
        fail(404,'Адрес не найден');
      }
      if(k==='my-orders'||k==='orders') {
        auth.requireRole(user,k==='my-orders'?'customer':'staff');
        if(req.method==='GET' && parts.length===2) return send(200,{items:orders.filter(o=>k==='orders'||o.userId===user.id).map(o=>({...o,productName:linked('products',o.productId)?.name||'Товар удалён'}))});
        if(k==='my-orders'&&req.method==='POST'&&parts.length===2) {
          const p=linked('products',body.productId);if(!p||p.deletedAt) fail(422,'Выберите товар',{productId:'Товар не найден'});
          if(p.stock<1) fail(409,'Этот товар закончился');
          p.stock--;const order={id:nextOrder++,userId:user.id,customerName:user.fullName,productId:p.id,status:'new',pickupUntil:new Date(Date.now()+3*86400000).toISOString(),extended:false};orders.push(order);return send(201,order);
        }
        const order=orders.find(o=>o.id===Number(parts[2])&&(k==='orders'||o.userId===user.id));
        if(!order) fail(404,'Заказ не найден');
        if(k==='my-orders'&&req.method==='POST'&&parts[3]==='extend'&&parts.length===4) {
          if(order.extended||!['new','ready'].includes(order.status)) fail(409,'Этот заказ уже нельзя продлить');
          order.extended=true;order.pickupUntil=new Date(Date.parse(order.pickupUntil)+2*86400000).toISOString();return send(200,order);
        }
        if(k==='orders'&&req.method==='PUT'&&parts.length===3) {
          const allowed={new:['ready','cancelled'],ready:['completed','cancelled']};
          if(!allowed[order.status]?.includes(body.status)) fail(409,'Нельзя перевести заказ в этот статус');
          if(body.status==='cancelled') {const p=linked('products',order.productId);if(p)p.stock++;}
          order.status=body.status;return send(200,order);
        }
        fail(405,'Метод не поддерживается');
      }
      if (!kinds.includes(k) || parts.length > 4) fail(404, 'Адрес не найден');
      if(['suppliers','customers'].includes(k)) auth.requireRole(user,'staff','admin');
      if(req.method!=='GET') auth.requireRole(user,'staff','admin');
      if(q.get('hard')==='true'||parts[3]==='restore') auth.requireRole(user,'admin');
      if(user.role==='customer'&&(q.get('includeDeleted')==='true'||q.get('onlyDeleted')==='true')) fail(403,'Удалённые записи доступны сотрудникам');
      if (parts.length === 2) {
        if (req.method === 'GET') return send(200, list(k,q));
        if (req.method === 'POST') { const e = validate(k, body, seq[k]); seq[k]++; db[k].push(e); return send(201, expand(k,e)); }
      }
      if (parts.length === 3 && parts[2] === 'bulk-delete' && req.method === 'POST') {
        if (!Array.isArray(body?.ids) || body.ids.some(id => !Number.isSafeInteger(id) || id < 1)) fail(422,'Ошибка валидации',{ids:'Ожидается список идентификаторов'});
        const selected = db[k].filter(e => body.ids.includes(e.id) && !e.deletedAt);
        selected.forEach(e => checkDelete(k,e.id));
        selected.forEach(e => { e.deletedAt = new Date().toISOString(); });
        return send(200,{deleted:selected.length});
      }
      const id = Number(parts[2]), e = linked(k,id);
      if (!e || (user.role==='customer' && e.deletedAt)) fail(404, 'Запись не найдена');
      if (parts.length === 4 && parts[3] === 'restore' && req.method === 'POST') {
        const restored = validate(k,e,id); db[k][db[k].indexOf(e)] = restored; return send(200,expand(k,restored));
      }
      if (parts.length === 3) {
        if (req.method === 'GET') return send(200, expand(k,e));
        if (req.method === 'PUT') { const saved = validate(k,body,id,e.deletedAt); db[k][db[k].indexOf(e)] = saved; return send(200,expand(k,saved)); }
        if (req.method === 'DELETE') { checkDelete(k,id); if (q.get('hard') === 'true') db[k].splice(db[k].indexOf(e),1); else e.deletedAt = new Date().toISOString(); return send(204); }
      }
      fail(405, 'Метод не поддерживается');
    } catch (e) { send(e.status || 500, { message: e.message || 'Ошибка сервера', ...(e.errors && { errors: e.errors }) }); }
  });
}
module.exports = { createServer };
if (require.main === module) {
  const port = Number(arg('port',8080)), origin = arg('origin','http://localhost:5555');
  const server = createServer({origin, ttl: Number(arg('ttl',900)), sessionSeconds: Number(arg('session-seconds',3600))});
  server.on('error', error => {
    const report = () => {
      console.error(error.code === 'EADDRINUSE'
        ? `Порт ${port} занят другой программой. Проверьте: lsof -nP -iTCP:${port} -sTCP:LISTEN`
        : `Не удалось запустить API: ${error.message}`);
      process.exitCode = 1;
    };
    if (error.code !== 'EADDRINUSE') return report();
    const probe = http.get(`http://127.0.0.1:${port}/api/__health`, response => {
      let body = '';
      response.on('data', chunk => {
        body += chunk;
        if (body.length > 8192) probe.destroy(new Error('Unexpected response'));
      });
      response.on('end', () => {
        let health;
        try { health = JSON.parse(body); } catch { return report(); }
        if (response.statusCode === 200 && health.status === 'ok' && health.service === 'cosmetics') {
          console.log(`API магазина уже работает на http://localhost:${port}/api. Повторный запуск не нужен. Данные сохранены.`);
        } else { report(); }
      });
    });
    probe.setTimeout(2000, () => probe.destroy(new Error('Timeout')));
    probe.on('error', report);
  });
  server.listen(port,'127.0.0.1', () => console.log(`Cosmetics API: http://localhost:${port}/api; CORS: ${origin}; данные в памяти`));
}

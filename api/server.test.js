const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createServer} = require('./mock-server');
const seed = require('./seed.json');
async function withServer(run) {
  const server = createServer({log:false}); await new Promise(r => server.listen(0,'127.0.0.1',r));
  const root = `http://127.0.0.1:${server.address().port}/api`;
  const call = async (path, method='GET', data) => {
    const r = await fetch(root+path,{method,headers:{'Content-Type':'application/json'},body:data===undefined?undefined:JSON.stringify(data)});
    return {status:r.status, headers:r.headers, data:r.status===204?null:await r.json()};
  };
  try { await run(call); } finally { await new Promise(r => server.close(r)); }
}
test('health, CORS preflight, 500 and real delay', () => withServer(async call => {
  assert.equal((await call('/__health')).data.status,'ok');
  const preflight = await call('/products','OPTIONS');
  assert.equal(preflight.status,204); assert.equal(preflight.headers.get('access-control-allow-origin'),'http://localhost:5555');
  assert.match(preflight.headers.get('access-control-allow-methods'),/PUT/);
  assert.equal((await call('/products?__fail=500')).status,500);
  const start=Date.now(); await call('/products?__delay=100'); assert.ok(Date.now()-start>=90);
}));
test('server pagination, sorting, filters and expanded relations', () => withServer(async call => {
  const a=(await call('/products?page=1&size=10&sort=price,desc')).data;
  const b=(await call('/products?page=2&size=10&sort=price,desc')).data;
  assert.equal(a.total,30); assert.equal(a.items.length,10); assert.equal(b.page,2);
  assert.ok(a.items.every(x=>!b.items.some(y=>y.id===x.id))); assert.ok(a.items[9].priceKopecks>=b.items[0].priceKopecks);
  assert.ok(a.items[0].brand.id); assert.ok(!('brandId' in a.items[0]));
  assert.equal((await call('/products?search=COS-0001')).data.total,1);
  assert.equal((await call('/products?search=NOTFOUND')).data.total,0);
  assert.equal((await call('/products?onlyDeleted=true')).data.total,0);
  const filtered=(await call('/products?brandId=1&categoryId=1&minPrice=1000')).data;
  assert.ok(filtered.items.every(x=>x.brand.id===1 && x.priceKopecks>=100000 && x.categories.some(c=>c.id===1)));
}));
test('422 unique SKU/email and field validation; 409 keeps relations', () => withServer(async call => {
  const duplicate=await call('/products','POST',seed.products[0]);
  assert.equal(duplicate.status,422); assert.ok(duplicate.data.errors.sku);
  const customer=await call('/customers','POST',seed.customers[0]);
  assert.equal(customer.status,422); assert.ok(customer.data.errors.email);
  const bad=await call('/products','POST',{...seed.products[0],sku:'NEW-SKU',brandId:3});
  assert.equal(bad.status,422); assert.ok(bad.data.errors.brandId);
  assert.equal((await call('/suppliers/1','DELETE')).status,409);
  assert.equal((await call('/suppliers/1')).data.deletedAt,null);
  assert.equal((await call('/products/99999')).status,404);
}));
test('all five resources: create/read/update/delete/restore/bulk/hard', () => withServer(async call => {
  for (const kind of Object.keys(seed)) {
    const input=structuredClone(seed[kind][0]); input.name='Новая запись';
    if(kind==='products') input.sku='NEW-SKU';
    if(kind==='customers') { input.email='new@example.com'; input.card.number='LC-NEW'; }
    const created=await call('/'+kind,'POST',input); assert.equal(created.status,201,JSON.stringify(created));
    const id=created.data.id, url=`/${kind}/${id}`;
    assert.equal((await call(url)).data.name,'Новая запись');
    assert.equal((await call(url,'PUT',{...input,name:'Изменено'})).status,200);
    assert.equal((await call(url,'DELETE')).status,204);
    assert.ok((await call('/'+kind+'?onlyDeleted=true')).data.items.some(e=>e.id===id));
    assert.equal((await call(url+'/restore','POST',{})).status,200);
    assert.equal((await call('/'+kind+'?onlyDeleted=true')).data.total,0);
    assert.equal((await call('/'+kind+'/bulk-delete','POST',{ids:[id,id]})).data.deleted,1);
    assert.equal((await call(url,'DELETE')).status,204);
    assert.equal((await call(url+'?hard=true','DELETE')).status,204);
    assert.equal((await call(url)).status,404);
  }
}));
test('bulk conflict is atomic; server ignores supplied id and deletedAt',()=>withServer(async call=>{
 const x=await call('/suppliers','POST',{...seed.suppliers[0],id:1,deletedAt:'2000-01-01'});
 assert.notEqual(x.data.id,1);assert.equal(x.data.deletedAt,null);
 const r=await call('/suppliers/bulk-delete','POST',{ids:[x.data.id,1]});assert.equal(r.status,409);
 assert.equal((await call('/suppliers/'+x.data.id)).data.deletedAt,null);
}));

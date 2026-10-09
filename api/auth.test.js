const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createServer}=require('./mock-server');
async function scenario(run,options={}) {
 const server=createServer({log:false,...options});await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base=`http://127.0.0.1:${server.address().port}/api`;
 const call=async(path,method='GET',body,token)=>{const res=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token&&{Authorization:'Bearer '+token})},body:body===undefined?undefined:JSON.stringify(body)});return {status:res.status,data:res.status===204?null:await res.json()};};
 const login=async(name)=> (await call('/auth/login','POST',{username:name,password:{buyer:'Buyer123!',staff:'Staff123!',admin:'Admin123!'}[name]})).data;
 try{await run(call,login);}finally{await new Promise(r=>server.close(r));}
}
test('guest 401, invalid password 401, login never returns password/hash',()=>scenario(async(call,login)=>{
 assert.equal((await call('/products')).status,401);assert.equal((await call('/auth/login','POST',{username:'admin',password:'bad'})).status,401);
 const a=await login('admin');assert.ok(a.accessToken);assert.ok(a.refreshToken);assert.deepEqual(Object.keys(a.user).sort(),['email','fullName','id','role','username']);
}));
test('registration validates password, refuses duplicate and ignores supplied admin role',()=>scenario(async(call)=>{
 const data={username:'new_user',password:'weak',fullName:'Новый покупатель',email:'new@example.com',role:'admin'};
 const bad=await call('/auth/register','POST',data);assert.equal(bad.status,422);assert.ok(bad.data.errors.password);
 data.password='Password123!';const created=await call('/auth/register','POST',data);assert.equal(created.status,201);assert.equal(created.data.role,'customer');
 assert.equal((await call('/auth/register','POST',data)).status,422);
}));
test('role matrix: customer reads catalogue but cannot mutate, view customers or deleted',()=>scenario(async(call,login)=>{
 const {accessToken:t}=await login('buyer');
 for(const path of ['/products','/brands','/categories','/account','/my-orders'])assert.equal((await call(path,'GET',undefined,t)).status,200,path);
 for(const path of ['/customers','/suppliers','/admin/users','/orders','/products?onlyDeleted=true'])assert.equal((await call(path,'GET',undefined,t)).status,403,path);
 assert.equal((await call('/products/1','DELETE',undefined,t)).status,403);
 assert.equal((await call('/products','POST',{},t)).status,403);
}));
test('staff has orders, catalogue edits; admin alone restores and manages users',()=>scenario(async(call,login)=>{
 const staff=(await login('staff')).accessToken,admin=(await login('admin')).accessToken;
 assert.equal((await call('/orders','GET',undefined,staff)).status,200);
 assert.equal((await call('/categories','POST',{name:'Новая категория',description:''},staff)).status,201);
 assert.equal((await call('/products/1?hard=true','DELETE',undefined,staff)).status,403);
 assert.equal((await call('/products/1/restore','POST',{},staff)).status,403);
 assert.equal((await call('/admin/users','GET',undefined,staff)).status,403);
 assert.equal((await call('/account','GET',undefined,staff)).status,403);
 assert.equal((await call('/admin/stats','GET',undefined,admin)).status,200);
 assert.equal((await call('/orders','GET',undefined,admin)).status,403);
 assert.equal((await call('/products/1/restore','POST',{},admin)).status,200);
}));
test('signed token rejects modified role and arbitrary forged token',()=>scenario(async(call,login)=>{
 const a=await login('buyer'),parts=a.accessToken.split('.');const payload=JSON.parse(Buffer.from(parts[1],'base64url'));payload.role='admin';parts[1]=Buffer.from(JSON.stringify(payload)).toString('base64url');
 assert.equal((await call('/admin/users','GET',undefined,parts.join('.'))).status,401);
 assert.equal((await call('/admin/users','GET',undefined,a.accessToken)).status,403);
}));
test('refresh rotates once, expired access renews, logout revokes whole session',async()=>{
 let time=Date.now();await scenario(async(call,login)=>{
 const a=await login('buyer');time+=61000;assert.equal((await call('/products','GET',undefined,a.accessToken)).status,401);
 const r=await call('/auth/refresh','POST',{refreshToken:a.refreshToken});assert.equal(r.status,200);assert.notEqual(r.data.refreshToken,a.refreshToken);
 assert.equal((await call('/auth/refresh','POST',{refreshToken:a.refreshToken})).status,401);
 assert.equal((await call('/products','GET',undefined,r.data.accessToken)).status,200);
 await call('/auth/logout','POST',{refreshToken:r.data.refreshToken});
 assert.equal((await call('/products','GET',undefined,r.data.accessToken)).status,401);
 assert.equal((await call('/auth/refresh','POST',{refreshToken:r.data.refreshToken})).status,401);
 },{ttl:60,now:()=>time});
});
test('absolute session deadline cannot be extended with refresh',async()=>{
 let time=Date.now();await scenario(async(call,login)=>{
 const a=await login('buyer');time+=31000;assert.equal((await call('/auth/refresh','POST',{refreshToken:a.refreshToken})).status,401);
 },{sessionSeconds:30,now:()=>time});
});
test('customers see own orders, can extend once; staff can process',()=>scenario(async(call,login)=>{
 const buyer=(await login('buyer')).accessToken,staff=(await login('staff')).accessToken;
 const order=await call('/my-orders','POST',{productId:1,userId:999},buyer);assert.equal(order.status,201);assert.equal(order.data.userId,1);
 await call('/auth/register','POST',{username:'other',password:'Other123!',fullName:'Другой покупатель',email:'other@example.com'});
 const other=(await call('/auth/login','POST',{username:'other',password:'Other123!'})).data.accessToken;
 assert.equal((await call('/my-orders','GET',undefined,other)).data.items.length,0);
 assert.equal((await call(`/my-orders/${order.data.id}/extend`,'POST',{},other)).status,404);
 assert.equal((await call(`/my-orders/${order.data.id}/extend`,'POST',{},buyer)).status,200);
 assert.equal((await call(`/my-orders/${order.data.id}/extend`,'POST',{},buyer)).status,409);
 assert.equal((await call(`/orders/${order.data.id}`,'PUT',{status:'ready'},staff)).status,200);
}));
test('admin changes role, revokes prior sessions, cannot demote self',()=>scenario(async(call,login)=>{
 const admin=(await login('admin')).accessToken,buyer=await login('buyer');
 assert.equal((await call('/admin/users/1/role','PUT',{role:'staff'},admin)).status,200);
 assert.equal((await call('/products','GET',undefined,buyer.accessToken)).status,401);
 assert.equal((await call('/auth/refresh','POST',{refreshToken:buyer.refreshToken})).status,401);
 assert.equal((await call('/admin/users/3/role','PUT',{role:'customer'},admin)).status,409);
}));

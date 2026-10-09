'use strict';
const crypto = require('node:crypto');
const fail = (status, message, errors) => { throw {status,message,...(errors && {errors})}; };
const hash = text => crypto.createHash('sha256').update(text).digest('hex');
function createAuth({ttl=900, sessionSeconds=3600, now=()=>Date.now()}={}) {
  const secret=crypto.randomBytes(32), users=[], sessions=new Map(), refreshes=new Map();
  let nextId=1;
  const publicUser = ({id,username,fullName,email,role})=>({id,username,fullName,email,role});
  const passwordHash = (password,salt)=>crypto.scryptSync(password,salt,32).toString('hex');
  function add(username,password,fullName,email,role) {
    const salt=crypto.randomBytes(16).toString('hex');
    const u={id:nextId++,username,fullName,email,role,salt,passwordHash:passwordHash(password,salt)};
    users.push(u);return u;
  }
  add('buyer','Buyer123!','Валерия Храброва','buyer@example.com','customer');
  add('staff','Staff123!','Мария Иванова','staff@example.com','staff');
  add('admin','Admin123!','Елена Петрова','admin@example.com','admin');
  const revoke = sid => {sessions.delete(sid);for(const [key,value] of refreshes) if(value.sid===sid) refreshes.delete(key);};
  function issue(user,session) {
    const exp=Math.min(now()+ttl*1000,session.expiresAt);
    const header=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
    const payload=Buffer.from(JSON.stringify({sub:user.id,role:user.role,sid:session.id,exp:exp/1000,jti:crypto.randomUUID()})).toString('base64url');
    const signed=header+'.'+payload;
    const accessToken=signed+'.'+crypto.createHmac('sha256',secret).update(signed).digest('base64url');
    const refreshToken=crypto.randomBytes(32).toString('base64url');
    refreshes.set(hash(refreshToken),{sid:session.id,expiresAt:Math.min(now()+7*86400000,session.expiresAt)});
    return {accessToken,refreshToken,expiresIn:Math.max(0,Math.floor((exp-now())/1000)),sessionExpiresAt:new Date(session.expiresAt).toISOString(),user:publicUser(user)};
  }
  function authenticate(req) {
    const token=(req.headers.authorization||'').replace(/^Bearer /,'');
    try {
      const [h,p,s,...extra]=token.split('.');if(!h||!p||!s||extra.length) throw Error();
      const expected=crypto.createHmac('sha256',secret).update(h+'.'+p).digest();
      const signature=Buffer.from(s,'base64url');
      if(signature.length!==expected.length || !crypto.timingSafeEqual(signature,expected)) throw Error();
      const claim=JSON.parse(Buffer.from(p,'base64url').toString());
      const session=sessions.get(claim.sid), user=users.find(u=>u.id===claim.sub);
      if(!session||!user||session.userId!==user.id||session.expiresAt<=now()||claim.exp*1000<=now()) throw Error();
      return {user,session};
    } catch { fail(401,'Сессия истекла. Войдите снова.'); }
  }
  function requireRole(user,...roles) {if(!roles.includes(user.role)) fail(403,'У вашей роли нет доступа к этому действию.');}
  function handle(action,method,body,req) {
    if(action==='register' && method==='POST') {
      const {username,password,fullName,email}=body,errors={};
      if(typeof username!=='string'||!/^[a-zA-Z0-9_]{3,32}$/.test(username)) errors.username='От 3 до 32 латинских букв, цифр или подчёркиваний';
      if(typeof fullName!=='string'||fullName.trim().length<2||fullName.trim().length>120) errors.fullName='Введите имя: от 2 до 120 символов';
      if(typeof email!=='string'||email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) errors.email='Введите корректную почту';
      if(typeof password!=='string'||password.length<8||password.length>128||!/[0-9]/.test(password)||!/[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?`~]/.test(password)) errors.password='Пароль: 8–128 символов, цифра и специальный символ';
      if(users.some(u=>u.username.toLowerCase()===String(username).toLowerCase())) errors.username='Этот логин уже занят';
      if(users.some(u=>u.email.toLowerCase()===String(email).toLowerCase())) errors.email='Эта почта уже зарегистрирована';
      if(Object.keys(errors).length) fail(422,'Проверьте поля',errors);
      return {status:201,data:publicUser(add(username,password,fullName.trim(),email.trim(),'customer'))};
    }
    if(action==='login' && method==='POST') {
      const u=users.find(u=>u.username.toLowerCase()===String(body.username).toLowerCase());
      const password=typeof body.password==='string'&&body.password.length<=128?body.password:'';
      const actual=passwordHash(password,u?.salt||'invalid-user');
      if(!u||!crypto.timingSafeEqual(Buffer.from(actual,'hex'),Buffer.from(u.passwordHash,'hex'))) fail(401,'Неверный логин или пароль');
      const session={id:crypto.randomUUID(),userId:u.id,expiresAt:now()+sessionSeconds*1000};sessions.set(session.id,session);
      return {status:200,data:issue(u,session)};
    }
    if(action==='refresh' && method==='POST') {
      const key=hash(String(body.refreshToken)),stored=refreshes.get(key);refreshes.delete(key);
      const session=stored&&sessions.get(stored.sid),u=session&&users.find(u=>u.id===session.userId);
      if(!stored||!session||!u||stored.expiresAt<=now()||session.expiresAt<=now()) fail(401,'Сессия завершена. Войдите снова.');
      return {status:200,data:issue(u,session)};
    }
    if(action==='logout' && method==='POST') {
      const stored=refreshes.get(hash(String(body.refreshToken)));if(stored) revoke(stored.sid);
      try {revoke(authenticate(req).session.id);}catch{}
      return {status:204};
    }
    if(action==='me' && method==='GET') return {status:200,data:publicUser(authenticate(req).user)};
    fail(404,'Адрес не найден');
  }
  function changeRole(actor,id,role) {
    requireRole(actor,'admin');
    if(!['customer','staff','admin'].includes(role)) fail(422,'Проверьте роль',{role:'Неизвестная роль'});
    const u=users.find(u=>u.id===id);if(!u) fail(404,'Пользователь не найден');
    if(u.id===actor.id && role!=='admin') fail(409,'Нельзя изменить собственную роль администратора');
    if(u.role!==role) {u.role=role;for(const [sid,s] of sessions) if(s.userId===id) revoke(sid);}
    return publicUser(u);
  }
  return {authenticate,requireRole,handle,changeRole,listUsers:()=>users.map(publicUser),publicUser};
}
module.exports={createAuth};

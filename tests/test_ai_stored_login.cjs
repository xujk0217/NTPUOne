'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const raw = fs.readFileSync('NTPUOne/AIAssistant/AILoginDiagnostics.swift','utf8').split('enum AIStoredSchoolLoginScript {')[1];
const script = name => raw.split(`static let ${name} = #"""`)[1].split('"""#')[0];
function fixture() {
  class Input {
    constructor(type,name) { Object.assign(this,{type,name,id:'',autocomplete:'',disabled:false,assigned:''}); }
    set value(v) { this.assigned=v; }
    get value() { throw Error('must not read a credential or hidden value'); }
    dispatchEvent() {}
  }
  const account = new Input('text','account'), password = new Input('password','password'), hidden = new Input('hidden','AuthState');
  const inputs = [account,password,hidden];
  const form = {method:'post',action:'https://saml2.ntpu.edu.tw/module.php/ntpuauth/login',submitted:0,
    getAttribute(){return this.action;},querySelectorAll:()=>inputs,
    querySelector:s=>s.includes('account')?account:password,requestSubmit(){this.submitted++;}};
  const document = {forms:[form],querySelector:()=>null,querySelectorAll:()=>inputs};
  const location = new URL(form.action);
  return {account,password,hidden,inputs,form,document,location,context:{URL,document,location,HTMLInputElement:Input,Event:class {},username:'fixture-user',secret:'fixture-password'}};
}
const run = (name,f) => vm.runInNewContext(`(function(){${script(name)}})()`,f.context);
let f=fixture(); assert.equal(run('preflight',f),true); assert.equal(f.account.assigned,'');
assert.equal(run('source',f),true); assert.equal(f.form.submitted,1); assert.equal(f.account.assigned,'fixture-user'); assert.equal(f.password.assigned,'fixture-password'); assert.equal(f.hidden.assigned,'');
const cases = [
 f=>f.context.location=new URL('https://evil.example/module.php/ntpuauth/login'),
 f=>f.context.location=new URL('http://saml2.ntpu.edu.tw/module.php/ntpuauth/login'),
 f=>f.context.location=new URL('https://saml2.ntpu.edu.tw/unknown'),
 f=>f.form.action='https://evil.example/module.php/ntpuauth/login',
 f=>f.form.action='https://saml2.ntpu.edu.tw/unknown',
 f=>f.form.method='get',
 f=>f.document.forms.push(f.form),
 f=>f.inputs.push({type:'password',name:'extra'}),
 f=>f.document.querySelector=()=>({}),
 f=>f.inputs.push({type:'text',name:'otp'}),
 f=>f.inputs.pop(),
 f=>f.password.disabled=true,
 f=>f.form.requestSubmit=null,
];
for(const mutate of cases) for(const name of ['preflight','source']) {
 f=fixture(); mutate(f); assert.equal(run(name,f),false); assert.equal(f.account.assigned,''); assert.equal(f.password.assigned,''); assert.equal(f.form.submitted,0);
}
f=fixture(); f.account.dispatchEvent=()=>{f.form.action='https://evil.example/';};
assert.equal(run('source',f),false); assert.equal(f.form.submitted,0); assert.equal(f.account.assigned,''); assert.equal(f.password.assigned,'');
console.log('Stored school login: trusted form, no hidden-value reads, fail-closed destinations, CAPTCHA/OTP and changed-form guards: PASS');

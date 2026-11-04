'use strict';
// Exercise the injected script with a synthetic site and synthetic SSE stream.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('NTPUOne/AIAssistant/NTPUAIWebBridge.swift', 'utf8').split('private static let script = #"""')[1].split('"""#')[0];
const events = [];
const overlay = { classList: { contains: () => true } };
const input = { value: '', dispatchEvent() {} };
let clicks = 0, newChats = 0, fetches = 0, busy = false;
const elements = {
  'auth-overlay': overlay, input, 'user-email': { title: 'student@example.edu' },
  newChatBtn: { click() { newChats++; } },
  sendBtn: { disabled: false, classList: { contains: () => busy }, click() { if (busy) { busy = false; return; } clicks++; void window.fetch('/chat/stream', {method:'POST'}); } },
};
let attached = false;
elements.fileInput = { dispatchEvent() { void window.fetch('/upload', { method: 'POST' }).then(() => { attached = true; }); }, files: null };
const document = { getElementById: id => elements[id], querySelector: selector => selector === '#attachPreview .attach-chip-badge' && attached ? {} : null };
class DataTransfer { constructor() { this.files = []; this.items = { add: file => this.files.push(file) }; } }
class File { constructor(parts, name, options) { this.name = name; this.type = options.type; } }

const stream = 'data: {"type":"token","content":"你好"}\n\ndata: {"type":"token","content":"世界"}\n\ndata: {"type":"done"}\n\n';
const bytes = new TextEncoder().encode(stream);
const chunks = [bytes.slice(0, 35), bytes.slice(35, 39), bytes.slice(39)];
const response = () => ({ok:true, body:{}, clone() { let i=0; return {body:{getReader:()=>({read:async()=> i<chunks.length ? {value:chunks[i++],done:false} : {done:true}})}}; }});
const window = { fetch: async () => { fetches++; return response(); }, webkit: { messageHandlers: { ntpuAssistant: { postMessage: e => events.push(e) } } } };
const context = {window, document, sessionId:'s-abc123', location: { origin:'https://ai.ntpu.edu.tw', href:'https://ai.ntpu.edu.tw/' }, URL, AbortController, TextDecoder, Event, DataTransfer, File, Uint8Array, atob, setTimeout, getComputedStyle:()=>({display:'none'})};
vm.runInNewContext(source, context);
(async () => {
  assert.equal(window.__ntpuOneStatus(), true);
  assert.equal(await window.__ntpuOneSend('測試','request-1',true), true);
  await new Promise(resolve => setTimeout(resolve, 20));
  assert.equal(clicks, 1); assert.equal(newChats, 1); assert.equal(fetches, 1);
  assert.equal(events.filter(e=>e.kind==='token').map(e=>e.content).join(''), '你好世界');
  assert.equal(events.filter(e=>e.kind==='done').length, 1);
  assert.equal(await window.__ntpuOneSend('圖片','request-image',false, { name: 'fixture.jpg', mimeType: 'image/jpeg', data: Buffer.from('fixture').toString('base64') }), true);
  await new Promise(resolve => setTimeout(resolve, 20));
  assert.equal(elements.fileInput.files[0].type, 'image/jpeg'); assert.equal(clicks, 2);
  context.sessionId = 's-other';
  assert.equal(await window.__ntpuOneDeleteCurrent(), false);
  context.sessionId = 's-abc123';
  assert.equal(await window.__ntpuOneDeleteCurrent(), true);
  assert.equal(await window.__ntpuOneDeleteCurrent(), false);
  busy = true;
  const pending = window.__ntpuOneSend('cancelled','request-cancelled',false);
  window.__ntpuOneStop(); busy = false;
  assert.equal(await pending, false);
  assert.equal(clicks, 2);
  elements['user-email'].title = '';
  assert.equal(window.__ntpuOneStatus(), false);
  assert.equal(await window.__ntpuOneSend('test','request-2',false), false);
  assert.equal(clicks, 2);
  process.stdout.write('AI bridge synthetic stream: PASS\n');
})().catch(error=>{ console.error(error); process.exitCode=1; });

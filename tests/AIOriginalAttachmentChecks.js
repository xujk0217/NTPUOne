'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const swift = fs.readFileSync('NTPUOne/AIAssistant/NTPUAIWebBridge.swift', 'utf8');
const script = swift.split('private static let script = #"""')[1].split('"""#')[0];
function fixture({ fail = false, cancel = false } = {}) {
  let badge = false, sent = 0, file, uploads = 0;
  const events = [];
  const nodes = {
    'auth-overlay': { classList: { contains: () => true } },
    'user-email': { title: 'fixture@example.test' },
    input: { value: '', dispatchEvent() {} },
    sendBtn: { disabled: false, classList: { contains: () => false }, click() { sent++; events.push('send'); } },
    newChatBtn: { click() { badge = false; } },
    fileInput: {
      files: [],
      dispatchEvent() {
        file = this.files[0];
        sandbox.fetch('https://ai.ntpu.edu.tw/upload', { method: 'POST' }).then(r => { if (r.ok) badge = true; }).catch(() => {});
        if (cancel) setTimeout(() => sandbox.__ntpuOneStop(), 1);
      }
    }
  };
  const sandbox = {
    location: { origin: 'https://ai.ntpu.edu.tw' },
    document: {
      getElementById: id => nodes[id],
      querySelector: selector => {
        if (selector === '#attachPreview .attach-chip-badge') return badge ? {} : null;
        if (selector.includes('clear-attach')) return { click() { badge = false; } };
        return null;
      }
    },
    setTimeout, URL, Uint8Array, TextDecoder, AbortController,
    Event: class { constructor(type) { this.type = type; } },
    atob: value => Buffer.from(value, 'base64').toString('binary'),
    File: class { constructor(parts, name, options) { this.parts = parts; this.name = name; this.type = options.type; } },
    DataTransfer: class {
      constructor() { this.files = []; this.items = { add: file => this.files.push(file) }; }
    },
    fetch(url, opts) {
      assert.equal(url, 'https://ai.ntpu.edu.tw/upload');
      uploads++; events.push('upload');
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => { events.push(fail ? 'failed' : 'uploaded'); resolve({ ok: !fail }); }, 5);
        opts.signal.addEventListener('abort', () => { clearTimeout(timer); reject(new Error('aborted')); });
      });
    },
    webkit: { messageHandlers: { ntpuAssistant: { postMessage() {} } } }
  };
  sandbox.window = sandbox;
  vm.createContext(sandbox); vm.runInContext(script, sandbox);
  return { sandbox, result: () => ({ file, sent, uploads, events }) };
}
(async () => {
  for (const [name, mimeType, bytes] of [
    ['lecture.pdf', 'application/pdf', Buffer.from('%PDF-original-file-fixture')],
    ['photo.png', 'image/png', Buffer.from([137,80,78,71,13,10,26,10,1,2,3])],
    ['slides.pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation', Buffer.from('PK-original-office-fixture')]
  ]) {
    const f = fixture();
    assert.equal(await f.sandbox.__ntpuOneSend('Read attachment', 'fixture', true, { name, mimeType, data: bytes.toString('base64') }), true);
    const r = f.result();
    assert.equal(r.file.name, name); assert.equal(r.file.type, mimeType);
    assert.deepEqual(Buffer.from(r.file.parts[0]), bytes);
    assert.equal(r.sent, 1); assert.equal(r.uploads, 1);
    assert.deepEqual(r.events, ['upload', 'uploaded', 'send']);
  }
  for (const opts of [{ fail: true }, { cancel: true }]) {
    const f = fixture(opts);
    assert.equal(await f.sandbox.__ntpuOneSend('Read attachment', 'fixture', true, { name: 'file.pdf', mimeType: 'application/pdf', data: Buffer.from('%PDF-fixture').toString('base64') }), false);
    assert.equal(f.result().sent, 0);
  }
  console.log('PASS: original bytes/name/MIME, PDF/image/Office, upload-before-send, failure and cancellation');
})().catch(e => { console.error(e); process.exitCode = 1; });

'use strict';
// Optional isolated browser regression: NODE_PATH must provide playwright-core.
const {chromium} = require('playwright-core');
const fs = require('node:fs');
const assert = require('node:assert/strict');
(async () => {
  const source = fs.readFileSync('NTPUOne/AIAssistant/FloatingAIView.swift', 'utf8');
  const html = source.split('let html = """\n')[1].split('\n        """')[0]
    .replace('\\(script)', () => fs.readFileSync('NTPUOne/AIAssistant/markdown-renderer.bundle.js', 'utf8'));
  const browser = await chromium.launch({headless: true, executablePath: process.env.CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
  try {
    const page = await browser.newPage({viewport: {width: 300, height: 200}});
    await page.evaluate(() => { window.measurements = []; window.webkit = {messageHandlers: {ntpuMarkdownSize: {postMessage: value => window.measurements.push(value)}}}; });
    await page.setContent(html);
    const text = '這是測試訊息。'.repeat(45) + '\n\n|課程|時間|\n|---|---|\n|測試|08:10|\n\n$$x^2+y^2=z^2$$\n\n最後一行必須完整顯示。';
    await page.evaluate(text => { document.getElementById('content').innerHTML = NTPUMarkdown.md.render(text); window.ntpuReportSize(); }, text);
    await page.waitForFunction(() => { const last=window.measurements.at(-1), node=document.getElementById('content'); return last && last.width > 0 && last.height >= node.getBoundingClientRect().height + 10; });
    const first = await page.evaluate(() => ({reported: window.measurements.at(-1).height, actual: document.getElementById('content').getBoundingClientRect().height}));
    assert.ok(first.reported >= first.actual + 10);
    await page.setViewportSize({width: 190, height: 200});
    await page.waitForFunction(previous => { const last=window.measurements.at(-1), node=document.getElementById('content'); return last && last.height > previous && last.height >= node.getBoundingClientRect().height + 10 && Math.abs(last.width-node.getBoundingClientRect().width)<1; }, first.reported);
    const narrow = await page.evaluate(() => ({reported: window.measurements.at(-1).height, actual: document.getElementById('content').getBoundingClientRect().height}));
    assert.ok(narrow.reported > first.reported);
    assert.ok(narrow.reported >= narrow.actual + 10);
    await page.evaluate(() => { document.getElementById('content').innerHTML += '<p>串流新增文字。</p>'.repeat(12); });
    await page.waitForFunction(previous => { const last=window.measurements.at(-1), node=document.getElementById('content'); return last && last.height > previous && last.height >= node.getBoundingClientRect().height + 10; }, narrow.reported);
    const final = await page.evaluate(() => ({reported: window.measurements.at(-1).height, actual: document.getElementById('content').getBoundingClientRect().height}));
    assert.ok(final.reported > narrow.reported);
    assert.ok(final.reported >= final.actual + 10);
    console.log('Markdown responsive/streaming height and final-line space: PASS');
  } finally { await browser.close(); }
})().catch(error => { console.error(error.message); process.exitCode = 1; });

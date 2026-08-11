import { readFile, writeFile, rm } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const require = createRequire(import.meta.url);
const app = require(resolve(root, 'assets/js/app.js'));
const catalog = require(resolve(root, 'assets/js/i18n.js'));

const failures = [];
const pass = (message) => console.log(`PASS: ${message}`);
const check = (condition, message) => {
    if (condition) pass(message);
    else failures.push(message);
};

const index = await readFile(resolve(root, 'index.html'), 'utf8');
const sub = await readFile(resolve(root, 'sub.html'), 'utf8');
const appSource = await readFile(resolve(root, 'assets/js/app.js'), 'utf8');
const i18nSource = await readFile(resolve(root, 'assets/js/i18n.js'), 'utf8');
const css = await readFile(resolve(root, 'assets/css/main.css'), 'utf8');
const manifest = JSON.parse(await readFile(resolve(root, 'manifest.json'), 'utf8'));

check(index === sub, 'index.html and sub.html are synchronized');
check(manifest.version === '1.3.0', 'manifest release version is 1.3.0');
check(index.indexOf('assets/js/vendor-loader.js') < index.indexOf('assets/js/i18n.js') && index.indexOf('assets/js/i18n.js') < index.indexOf('assets/js/app.js'), 'local scripts load in deterministic order');
check(!index.includes('fonts.googleapis.com'), 'Google Fonts is not a critical-path dependency');
check(!index.includes('cdnjs.cloudflare.com/ajax/libs/qrious'), 'QR library is not eagerly loaded from a CDN');
check(css.includes('@media (prefers-reduced-motion: reduce)'), 'reduced-motion styles are present');
check(css.includes('@supports not ((backdrop-filter: blur(1px))'), 'glass fallback is present');
check(index.includes('role="progressbar"') && index.includes('aria-labelledby="qr-title"'), 'core accessibility semantics are present');
check(!index.includes('âœ•') && !index.includes('âˆž'), 'no known encoding artifacts remain');
check(!appSource.includes('TreeWalker') && !appSource.includes('reverseTranslations'), 'legacy DOM translation engine is absent');

const htmlKeys = new Set([...index.matchAll(/data-i18n(?:-aria-label)?="([^"]+)"/g)].map((m) => m[1]));
for (const lang of ['en', 'fa']) {
    const missing = [...htmlKeys].filter((key) => !catalog[lang][key]);
    check(missing.length === 0, `${lang.toUpperCase()} catalog covers all HTML translation keys${missing.length ? ` (${missing.join(', ')})` : ''}`);
}
check(Object.keys(catalog.en).length === Object.keys(catalog.fa).length, 'EN and FA catalogs contain the same number of keys');
check(Object.keys(catalog.en).every((key) => Object.hasOwn(catalog.fa, key)), 'EN and FA catalog keys are synchronized');
check(i18nSource.includes('Object.freeze'), 'translation catalog is immutable');

const now = Date.now();
const finite = 100 * 1024 * 1024;
const states = [
    ['active', { enabled: true, totalBytes: finite, usedBytes: finite / 2, expireSeconds: Math.floor((now + 3 * 86400000) / 1000) }],
    ['inactive', { enabled: false, totalBytes: finite, usedBytes: 0, expireSeconds: Math.floor((now + 3 * 86400000) / 1000) }],
    ['expired', { enabled: true, totalBytes: finite, usedBytes: 0, expireSeconds: Math.floor((now - 60000) / 1000) }],
    ['outOfData', { enabled: true, totalBytes: finite, usedBytes: finite, expireSeconds: Math.floor((now + 3 * 86400000) / 1000) }],
    ['unlimited', { enabled: true, totalBytes: 0, usedBytes: finite * 4, expireSeconds: 0 }]
];
for (const [expected, data] of states) {
    check(app.deriveSubscriptionState(data, now) === expected, `state engine resolves ${expected}`);
}
check(app.getDaysRemaining(0, now) === null, 'no-expiry plans return unlimited remaining days');
check(app.getDaysRemaining(Math.floor((now - 60000) / 1000), now) === 0, 'expired plans clamp remaining days to zero');

for (const file of ['assets/js/vendor-loader.js', 'assets/js/i18n.js', 'assets/js/app.js', 'scripts/sync-sub.mjs', 'scripts/validate.mjs']) {
    const syntax = spawnSync(process.execPath, ['--check', resolve(root, file)], { encoding: 'utf8' });
    check(syntax.status === 0, `${file} passes Node syntax validation`);
}

function staticFixture(source) {
    let html = source
        .replace(/\{\{[\s\S]*?\}\}/g, '')
        .replace(/data-up="[^"]*"/, 'data-up="10485760"')
        .replace(/data-down="[^"]*"/, 'data-down="20971520"')
        .replace(/data-total="[^"]*"/, 'data-total="104857600"')
        .replace(/data-expire="[^"]*"/, `data-expire="${Math.floor((Date.now() + 7 * 86400000) / 1000)}"`)
        .replace(/data-enabled="[^"]*"/, 'data-enabled="true"')
        .replace(/<p id="display-name" class="account-name">[\s\S]*?<\/p>/, '<p id="display-name" class="account-name">demo@example.com</p>')
        .replace(/<div id="raw-links-container" hidden>[\s\S]*?<\/div>\s*<main/, '<div id="raw-links-container" hidden><div class="raw-link">vless://demo@example.com:443#Amsterdam-01</div></div>\n\n    <main');
    return html;
}

const runtimeHarness = String.raw`
<script>
(() => {
    const errors = [];
    window.addEventListener('error', (e) => errors.push(e.message || 'window error'));
    window.addEventListener('unhandledrejection', (e) => errors.push(String(e.reason || 'unhandled rejection')));
    globalThis.QRious = function QRiousStub(options) { options.element.dataset.qrRendered = 'true'; };
    try {
        Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async () => {} } });
    } catch (_) {}

    document.addEventListener('DOMContentLoaded', () => setTimeout(async () => {
        const issues = [];
        const assert = (condition, message) => { if (!condition) issues.push(message); };
        const now = Date.now();
        const MB = 1024 * 1024;
        const cases = [
            ['active', { enabled:true, uploadBytes:10*MB, downloadBytes:20*MB, totalBytes:100*MB, usedBytes:30*MB, expireSeconds:Math.floor((now+3*86400000)/1000) }],
            ['inactive', { enabled:false, uploadBytes:0, downloadBytes:0, totalBytes:100*MB, usedBytes:0, expireSeconds:Math.floor((now+3*86400000)/1000) }],
            ['expired', { enabled:true, uploadBytes:1*MB, downloadBytes:1*MB, totalBytes:100*MB, usedBytes:2*MB, expireSeconds:Math.floor((now-60000)/1000) }],
            ['outOfData', { enabled:true, uploadBytes:50*MB, downloadBytes:50*MB, totalBytes:100*MB, usedBytes:100*MB, expireSeconds:Math.floor((now+3*86400000)/1000) }],
            ['unlimited', { enabled:true, uploadBytes:100*MB, downloadBytes:200*MB, totalBytes:0, usedBytes:300*MB, expireSeconds:0 }]
        ];

        for (const lang of ['en', 'fa']) {
            setLanguage(lang, false);
            assert(document.documentElement.dir === (lang === 'fa' ? 'rtl' : 'ltr'), 'direction:' + lang);
            assert(document.documentElement.lang === lang, 'lang:' + lang);
            for (const theme of ['theme-dark', 'theme-light']) {
                setTheme(theme, false);
                assert(document.documentElement.classList.contains(theme), 'theme:' + lang + ':' + theme);
                for (const [state, data] of cases) {
                    cachedRawData = data;
                    renderOverview();
                    assert(document.getElementById('status-badge').textContent === t(state), 'status:' + lang + ':' + theme + ':' + state);
                    assert(document.querySelector('.hero-card').dataset.state === state, 'hero-state:' + state);
                    const track = document.querySelector('.progress-track');
                    if (state === 'unlimited') {
                        assert(!track.hasAttribute('aria-valuenow'), 'unlimited-progress-value');
                        assert(track.getAttribute('aria-valuetext') === t('unlimited'), 'unlimited-progress-text');
                    } else {
                        assert(track.hasAttribute('aria-valuenow'), 'finite-progress-value:' + state);
                    }
                }
            }
        }

        const raw = document.getElementById('raw-links-container');
        for (const count of [0, 1, 3]) {
            raw.replaceChildren(...Array.from({ length: count }, (_, i) => {
                const node = document.createElement('div');
                node.className = 'raw-link';
                node.textContent = 'vless://demo@example.com:443#Node-' + (i + 1);
                return node;
            }));
            renderConfigs();
            assert(document.querySelectorAll('.config-card').length === count, 'config-count:' + count);
            assert((count === 0) === Boolean(document.querySelector('.empty-state')), 'empty-state:' + count);
        }

        setLanguage('en', false);
        raw.innerHTML = '<div class="raw-link">vless://demo@example.com:443#Amsterdam-01</div>';
        renderConfigs();
        const copyButton = document.querySelector('[data-config-action="copy"]');
        copyButton.click();
        await new Promise((resolve) => setTimeout(resolve, 25));
        assert(copyButton.textContent === t('copied'), 'copy-feedback');

        const qrButton = document.querySelector('[data-config-action="qr"]');
        qrButton.focus();
        qrButton.click();
        await new Promise((resolve) => setTimeout(resolve, 40));
        const dialog = document.getElementById('qr-dialog');
        assert(dialog.open || dialog.hasAttribute('open'), 'qr-dialog-open');
        assert(document.getElementById('qr-canvas').dataset.qrRendered === 'true', 'qr-render');
        document.getElementById('qr-close-bottom').click();
        await new Promise((resolve) => setTimeout(resolve, 40));
        assert(!dialog.open && !dialog.hasAttribute('open'), 'qr-dialog-close');
        assert(document.activeElement === qrButton, 'qr-focus-return');

        assert(document.querySelector('.skip-link') !== null, 'skip-link');
        assert(document.querySelector('[role="progressbar"]') !== null, 'progressbar');
        assert(document.getElementById('toast').getAttribute('aria-live') === 'polite', 'toast-live');

        issues.push(...errors.map((error) => 'runtime-error:' + error));
        const result = document.createElement('div');
        result.id = 'qa-result';
        result.dataset.status = issues.length ? 'fail' : 'pass';
        result.textContent = issues.length ? issues.join('|') : 'PASS';
        document.body.append(result);
    }, 0));
})();
</script>`;

const fixturePath = resolve(root, '.hyper-sentry-qa.html');
const fixture = staticFixture(index).replace('</body>', `${runtimeHarness}\n</body>`);
await writeFile(fixturePath, fixture);

if (process.env.P0W_QA_SKIP_BROWSER === '1') {
    console.log('SKIP: browser QA matrix (P0W_QA_SKIP_BROWSER=1)');
} else {
    const chromium = process.env.CHROMIUM || '/usr/bin/chromium';
    const browser = spawnSync(chromium, [
        '--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
        '--disable-background-networking', '--host-resolver-rules=MAP * 0.0.0.0',
        '--allow-file-access-from-files', '--virtual-time-budget=3500', '--dump-dom',
        `file://${fixturePath}`
    ], { encoding: 'utf8', timeout: 20000, maxBuffer: 8 * 1024 * 1024 });

    const dom = browser.stdout || '';
    check(browser.status === 0, 'Headless Chromium completed successfully');
    check(dom.includes('id="qa-result" data-status="pass"'), 'browser QA matrix passed EN/FA × light/dark × 5 states × config cases');
    if (!dom.includes('id="qa-result"')) {
        console.error('BROWSER_STDERR', browser.stderr);
        console.error('DOM_TAIL', dom.slice(-5000));
    }
    if (dom.includes('id="qa-result" data-status="fail"')) {
        const match = dom.match(/<div id="qa-result"[^>]*>(.*?)<\/div>/s);
        failures.push(`browser runtime: ${match?.[1] || 'unknown failure'}`);
    }
}

await rm(fixturePath, { force: true });

if (failures.length) {
    console.error('\nQA FAILURES');
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
}
console.log('\nHyperSentry comprehensive QA passed.');

import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';

const root = resolve(import.meta.dirname, '..');
const read = (file) => readFile(resolve(root, file), 'utf8');
const [index, sub, template, app, i18n, vendor, css, manifest, logo] = await Promise.all([
    read('index.html'),
    read('sub.html'),
    read('template.html'),
    read('assets/js/app.js'),
    read('assets/js/i18n.js'),
    read('assets/js/vendor-loader.js'),
    read('assets/css/main.css'),
    read('manifest.json'),
    readFile(resolve(root, 'assets/images/hyper-sentry-logo.webp'))
]);

const failures = [];
const check = (condition, message) => { if (!condition) failures.push(message); };
const digest = (value) => createHash('sha256').update(value).digest('hex');
const parsedManifest = JSON.parse(manifest);

let expected = template;
for (const [token, value] of [
    ['@@HYPER_SENTRY_CSS@@', css],
    ['@@HYPER_SENTRY_VENDOR_JS@@', vendor],
    ['@@HYPER_SENTRY_I18N_JS@@', i18n],
    ['@@HYPER_SENTRY_APP_JS@@', app],
    ['@@HYPER_SENTRY_LOGO_DATA@@', `data:image/webp;base64,${logo.toString('base64')}`]
]) {
    expected = expected.replace(token, value);
}

check(digest(index) === digest(sub), 'index.html and sub.html must be identical');
check(digest(index) === digest(expected), 'production HTML must be rebuilt from template.html and source assets');
check(parsedManifest.version === '1.3.2', 'manifest version must be 1.3.2');
check(index.includes('<style id="hyper-sentry-styles">'), 'production CSS must be inlined');
check(index.includes('<script id="hyper-sentry-vendor">'), 'vendor loader must be inlined');
check(index.includes('<script id="hyper-sentry-i18n">'), 'i18n catalog must be inlined');
check(index.includes('<script id="hyper-sentry-app">'), 'application script must be inlined');
check(index.indexOf('id="hyper-sentry-vendor"') < index.indexOf('id="hyper-sentry-i18n"') && index.indexOf('id="hyper-sentry-i18n"') < index.indexOf('id="hyper-sentry-app"'), 'inline scripts must load in deterministic order');
check(!/\b(?:src|href)=["']assets\//.test(index), 'production HTML must not reference relative theme assets');
check(!index.includes('assets/css/main.css') && !index.includes('assets/js/app.js') && !index.includes('assets/js/i18n.js'), 'legacy external production asset references must be absent');
check(index.includes('data:image/webp;base64,'), 'official HyperSentry logo must be embedded');
check(!app.includes('TreeWalker'), 'legacy DOM text translation must not return');
check(index.includes('role="progressbar"'), 'progressbar semantics are required');
check(index.includes('aria-labelledby="qr-title"'), 'QR dialog must have an accessible name');
check(!css.includes('prefers-reduced-motion'), 'reduced-motion override must remain absent');
check(css.includes('@keyframes hs-rise-in') && css.includes('@keyframes hs-dialog-in'), 'lightweight UI animations are required');
check(!template.includes('qr-close-bottom'), 'QR dialog must keep only the top close control');
check(i18n.includes('HYPER_SENTRY_I18N'), 'translation catalog is missing');
check(!index.includes('âœ•') && !index.includes('âˆž'), 'broken UTF-8 artifacts detected');

if (failures.length) {
    console.error(failures.map((item) => `FAIL: ${item}`).join('\n'));
    process.exit(1);
}
console.log('HyperSentry validation passed');

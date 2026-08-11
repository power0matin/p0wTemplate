import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';

const root = resolve(import.meta.dirname, '..');
const read = (file) => readFile(resolve(root, file), 'utf8');
const [index, sub, app, i18n, css] = await Promise.all([
    read('index.html'), read('sub.html'), read('assets/js/app.js'), read('assets/js/i18n.js'), read('assets/css/main.css')
]);

const failures = [];
const check = (condition, message) => { if (!condition) failures.push(message); };
const digest = (value) => createHash('sha256').update(value).digest('hex');

check(digest(index) === digest(sub), 'index.html and sub.html must be identical');
check(index.includes('assets/js/i18n.js') && index.indexOf('assets/js/i18n.js') < index.indexOf('assets/js/app.js'), 'i18n.js must load before app.js');
check(!app.includes('TreeWalker'), 'legacy DOM text translation must not return');
check(index.includes('role="progressbar"'), 'progressbar semantics are required');
check(index.includes('aria-labelledby="qr-title"'), 'QR dialog must have an accessible name');
check(css.includes('@media (prefers-reduced-motion: reduce)'), 'reduced-motion support is required');
check(i18n.includes('HYPER_SENTRY_I18N'), 'translation catalog is missing');
check(!index.includes('âœ•') && !index.includes('âˆž'), 'broken UTF-8 artifacts detected');

if (failures.length) {
    console.error(failures.map((item) => `FAIL: ${item}`).join('\n'));
    process.exit(1);
}
console.log('HyperSentry validation passed');

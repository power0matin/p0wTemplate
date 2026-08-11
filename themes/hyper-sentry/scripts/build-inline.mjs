import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const readText = (file) => readFile(resolve(root, file), 'utf8');

const [template, css, vendor, i18n, app, logo] = await Promise.all([
    readText('template.html'),
    readText('assets/css/main.css'),
    readText('assets/js/vendor-loader.js'),
    readText('assets/js/i18n.js'),
    readText('assets/js/app.js'),
    readFile(resolve(root, 'assets/images/hyper-sentry-logo.webp'))
]);

const replacements = new Map([
    ['@@HYPER_SENTRY_CSS@@', css],
    ['@@HYPER_SENTRY_VENDOR_JS@@', vendor],
    ['@@HYPER_SENTRY_I18N_JS@@', i18n],
    ['@@HYPER_SENTRY_APP_JS@@', app],
    ['@@HYPER_SENTRY_LOGO_DATA@@', `data:image/webp;base64,${logo.toString('base64')}`]
]);

let output = template;
for (const [token, value] of replacements) {
    if (!output.includes(token)) throw new Error(`Missing build token: ${token}`);
    output = output.replaceAll(token, value);
}

const unresolved = output.match(/@@HYPER_SENTRY_[A-Z0-9_]+@@/g);
if (unresolved) throw new Error(`Unresolved build tokens: ${unresolved.join(', ')}`);

if (/\b(?:src|href)=["']assets\//.test(output)) {
    throw new Error('Production HTML still contains relative theme assets');
}

await Promise.all([
    writeFile(resolve(root, 'index.html'), output),
    writeFile(resolve(root, 'sub.html'), output)
]);
console.log('Built self-contained HyperSentry index.html and sub.html');

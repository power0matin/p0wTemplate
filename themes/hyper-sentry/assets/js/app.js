'use strict';

const I18N = typeof globalThis !== 'undefined' && globalThis.HYPER_SENTRY_I18N
    ? globalThis.HYPER_SENTRY_I18N
    : (typeof require === 'function' ? require('./i18n.js') : { en: {}, fa: {} });

const hasDocument = typeof document !== 'undefined';
let currentLang = hasDocument && document.documentElement.lang === 'fa' ? 'fa' : 'en';
let cachedRawData = null;

function t(key) {
    return I18N[currentLang][key] || I18N.en[key] || key;
}

function applyTranslations(root = document) {
    root.querySelectorAll('[data-i18n]').forEach((element) => {
        const key = element.dataset.i18n;
        if (I18N[currentLang][key]) {
            element.textContent = I18N[currentLang][key];
        }
    });

    root.querySelectorAll('[data-i18n-aria-label]').forEach((element) => {
        const key = element.dataset.i18nAriaLabel;
        if (I18N[currentLang][key]) {
            element.setAttribute('aria-label', I18N[currentLang][key]);
        }
    });

    const langToggle = document.getElementById('lang-toggle');
    if (langToggle) {
        langToggle.textContent = currentLang === 'fa' ? 'EN' : 'FA';
        langToggle.setAttribute('aria-label', t('switchLanguage'));
    }

    const themeToggle = document.getElementById('theme-toggle');
    if (themeToggle) {
        themeToggle.setAttribute('aria-label', t('toggleTheme'));
    }
}

function setLanguage(lang, persist = true) {
    currentLang = lang === 'fa' ? 'fa' : 'en';
    document.documentElement.lang = currentLang;
    document.documentElement.dir = currentLang === 'fa' ? 'rtl' : 'ltr';
    if (persist) {
        localStorage.setItem('p0wtemplate-lang', currentLang);
    }
    applyTranslations();
    renderOverview();
    renderConfigs();
}

function initLanguage() {
    const saved = localStorage.getItem('p0wtemplate-lang') || localStorage.getItem('neo-lang') || currentLang;
    setLanguage(saved, true);

    document.getElementById('lang-toggle')?.addEventListener('click', () => {
        setLanguage(currentLang === 'fa' ? 'en' : 'fa');
    });
}

function setTheme(theme, persist = true) {
    const next = theme === 'theme-light' ? 'theme-light' : 'theme-dark';
    document.documentElement.classList.remove('theme-light', 'theme-dark');
    document.documentElement.classList.add(next);
    if (persist) {
        localStorage.setItem('hyper-sentry-theme', next);
    }
}

function initTheme() {
    const saved = localStorage.getItem('hyper-sentry-theme');
    const fallback = window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'theme-light' : 'theme-dark';
    setTheme(saved || fallback, Boolean(saved));

    document.getElementById('theme-toggle')?.addEventListener('click', () => {
        setTheme(document.documentElement.classList.contains('theme-light') ? 'theme-dark' : 'theme-light');
    });
}

function parseBool(value) {
    return /^(true|1|yes|on)$/i.test(String(value || '').trim());
}

function toSafeInt(value) {
    const parsed = Number.parseInt(value || '0', 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function readRawData() {
    if (cachedRawData) return cachedRawData;
    const raw = document.getElementById('raw-data');
    cachedRawData = {
        uploadBytes: toSafeInt(raw?.dataset.up),
        downloadBytes: toSafeInt(raw?.dataset.down),
        totalBytes: toSafeInt(raw?.dataset.total),
        expireSeconds: toSafeInt(raw?.dataset.expire),
        enabled: parseBool(raw?.dataset.enabled)
    };
    cachedRawData.usedBytes = cachedRawData.uploadBytes + cachedRawData.downloadBytes;
    return cachedRawData;
}

function formatBytes(bytes) {
    const safeBytes = Math.max(0, Number(bytes) || 0);
    if (safeBytes === 0) return { value: '0', unit: 'B', text: '0 B' };
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    const index = Math.min(Math.floor(Math.log(safeBytes) / Math.log(1024)), units.length - 1);
    const value = safeBytes / Math.pow(1024, index);
    const formatted = new Intl.NumberFormat(currentLang === 'fa' ? 'fa-IR' : 'en-US', {
        maximumFractionDigits: value >= 100 ? 0 : value >= 10 ? 1 : 2
    }).format(value);
    return { value: formatted, unit: units[index], text: `${formatted} ${units[index]}` };
}

function getDaysRemaining(expireSeconds, nowMs = Date.now()) {
    if (!expireSeconds) return null;
    return Math.max(0, Math.ceil((expireSeconds * 1000 - nowMs) / 86400000));
}

function formatExpiry(expireSeconds) {
    if (!expireSeconds) return t('neverExpires');
    return new Intl.DateTimeFormat(currentLang === 'fa' ? 'fa-IR' : 'en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    }).format(new Date(expireSeconds * 1000));
}

function deriveSubscriptionState({ enabled, totalBytes, usedBytes, expireSeconds }, nowMs = Date.now()) {
    const expired = expireSeconds > 0 && expireSeconds * 1000 <= nowMs;
    const quotaExhausted = totalBytes > 0 && usedBytes >= totalBytes;

    // Show the most useful reason first. 3x-ui may disable a client after
    // expiration/quota exhaustion, so those explicit conditions take priority.
    if (expired) return 'expired';
    if (quotaExhausted) return 'outOfData';
    if (!enabled) return 'inactive';
    if (totalBytes === 0) return 'unlimited';
    return 'active';
}

function getStateClass(state) {
    return {
        active: 'status-active',
        unlimited: 'status-unlimited',
        inactive: 'status-inactive',
        expired: 'status-expired',
        outOfData: 'status-out-of-data'
    }[state] || 'status-inactive';
}

function renderOverview() {
    const data = readRawData();
    const state = deriveSubscriptionState(data);
    const unlimitedData = data.totalBytes === 0;
    const remaining = unlimitedData ? null : Math.max(0, data.totalBytes - data.usedBytes);
    const remainingFormatted = remaining === null ? null : formatBytes(remaining);
    const usedFormatted = formatBytes(data.usedBytes);
    const days = getDaysRemaining(data.expireSeconds);

    document.getElementById('hero-rem-val').textContent = remainingFormatted ? remainingFormatted.value : '∞';
    document.getElementById('hero-rem-unit').textContent = remainingFormatted ? remainingFormatted.unit : '';
    document.getElementById('detail-used').textContent = usedFormatted.text;
    document.getElementById('days-left').textContent = days === null
        ? '∞'
        : new Intl.NumberFormat(currentLang === 'fa' ? 'fa-IR' : 'en-US').format(days);

    const hero = document.querySelector('.hero-card');
    if (hero) hero.dataset.state = state;

    const badge = document.getElementById('status-badge');
    badge.dataset.i18n = state;
    badge.textContent = t(state);
    badge.className = `status-badge ${getStateClass(state)}`;
    document.getElementById('detail-status').textContent = t(state);

    document.getElementById('detail-total').textContent = unlimitedData ? t('unlimited') : formatBytes(data.totalBytes).text;
    document.getElementById('detail-upload').textContent = formatBytes(data.uploadBytes).text;
    document.getElementById('detail-download').textContent = formatBytes(data.downloadBytes).text;
    document.getElementById('detail-expiry').textContent = formatExpiry(data.expireSeconds);

    const progress = document.getElementById('progress-bar');
    progress.className = 'progress-fill';
    const progressTrack = progress.parentElement;
    progressTrack?.classList.remove('is-unlimited');

    if (unlimitedData) {
        progressTrack?.classList.add('is-unlimited');
        progress.style.inlineSize = '0%';
        progressTrack?.removeAttribute('aria-valuenow');
        progressTrack?.setAttribute('aria-valuetext', t('unlimited'));
        return;
    }

    const percent = Math.min(100, data.totalBytes > 0 ? (data.usedBytes / data.totalBytes) * 100 : 0);
    progress.style.inlineSize = `${percent}%`;
    progressTrack?.setAttribute('aria-valuenow', String(Math.round(percent)));
    progressTrack?.setAttribute('aria-valuetext', `${Math.round(percent)}%`);
    if (percent >= 90) progress.classList.add('is-danger');
    else if (percent >= 75) progress.classList.add('is-warning');
}

function initAvatar() {
    const name = document.getElementById('display-name')?.textContent.trim() || '';
    const avatar = document.getElementById('user-avatar');
    if (avatar && name) avatar.textContent = name.charAt(0).toUpperCase();
}

function getRawLinks() {
    return Array.from(document.querySelectorAll('#raw-links-container .raw-link'))
        .map((node) => node.textContent.trim())
        .filter(Boolean);
}

const PROTOCOL_META = Object.freeze({
    vless: { label: 'VLESS', badge: 'VL' },
    vmess: { label: 'VMess', badge: 'VM' },
    trojan: { label: 'Trojan', badge: 'TR' },
    ss: { label: 'Shadowsocks', badge: 'SS' },
    shadowsocks: { label: 'Shadowsocks', badge: 'SS' },
    hysteria2: { label: 'Hysteria2', badge: 'H2' },
    hy2: { label: 'Hysteria2', badge: 'H2' },
    tuic: { label: 'TUIC', badge: 'TU' },
    wireguard: { label: 'WireGuard', badge: 'WG' },
    socks: { label: 'SOCKS', badge: 'SO' },
    http: { label: 'HTTP', badge: 'HT' },
    https: { label: 'HTTPS', badge: 'HS' }
});

function normalizeProtocol(protocol) {
    return String(protocol || 'vpn').toLowerCase().replace(/[^a-z0-9-]/g, '') || 'vpn';
}

function getConfigMeta(link, index) {
    let name = `${t('config')} ${index + 1}`;
    let protocol = 'vpn';
    try {
        const hashIndex = link.indexOf('#');
        if (hashIndex >= 0 && hashIndex < link.length - 1) {
            name = decodeURIComponent(link.slice(hashIndex + 1));
        }
        const protocolIndex = link.indexOf('://');
        if (protocolIndex > 0) protocol = link.slice(0, protocolIndex).toLowerCase();
    } catch (_) {}

    const normalized = normalizeProtocol(protocol);
    const meta = PROTOCOL_META[normalized] || {
        label: normalized.toUpperCase(),
        badge: normalized.slice(0, 2).toUpperCase()
    };
    return { name, protocol: normalized, protocolLabel: meta.label, protocolBadge: meta.badge };
}

function createConfigButton({ action, label, className, link, name }) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = className;
    button.dataset.configAction = action;
    button.dataset.link = link;
    button.dataset.name = name;
    button.textContent = label;
    button.setAttribute('aria-label', `${label}: ${name}`);
    return button;
}

function renderConfigs() {
    const container = document.getElementById('configs-container');
    if (!container) return;
    const links = getRawLinks();
    const countBadge = document.getElementById('config-count');
    const formattedCount = new Intl.NumberFormat(currentLang === 'fa' ? 'fa-IR' : 'en-US').format(links.length);
    countBadge.textContent = formattedCount;
    countBadge.setAttribute('aria-label', `${t('configsCount')}: ${formattedCount}`);
    container.replaceChildren();

    if (!links.length) {
        const empty = document.createElement('div');
        empty.className = 'empty-state glass-pane';
        empty.textContent = t('noConfigs');
        container.append(empty);
        return;
    }

    const fragment = document.createDocumentFragment();
    links.forEach((link, index) => {
        const { name, protocol, protocolLabel, protocolBadge } = getConfigMeta(link, index);
        const card = document.createElement('article');
        card.className = 'config-card glass-pane';

        const identity = document.createElement('div');
        identity.className = 'config-identity';

        const badge = document.createElement('span');
        badge.className = `protocol-badge protocol-${protocol}`;
        badge.textContent = protocolBadge;
        badge.title = protocolLabel;
        badge.setAttribute('aria-label', `${t('protocol')}: ${protocolLabel}`);

        const copy = document.createElement('div');
        copy.className = 'config-copy';
        const title = document.createElement('h3');
        title.textContent = name;
        title.title = name;
        const protocolText = document.createElement('p');
        protocolText.textContent = protocolLabel;
        copy.append(title, protocolText);
        identity.append(badge, copy);

        const actions = document.createElement('div');
        actions.className = 'config-actions';
        const copyButton = createConfigButton({
            action: 'copy',
            label: t('copy'),
            className: 'mini-button config-copy-button',
            link,
            name
        });
        const qrButton = createConfigButton({
            action: 'qr',
            label: 'QR',
            className: 'mini-button mini-button-accent config-qr-button',
            link,
            name
        });
        qrButton.setAttribute('aria-label', `${t('showQr')}: ${name}`);
        actions.append(copyButton, qrButton);
        card.append(identity, actions);
        fragment.append(card);
    });
    container.append(fragment);
}

const buttonResetTimers = new WeakMap();
function showTemporaryButtonState(button, label, restoreLabel, duration = 1300) {
    if (!button) return;
    const existing = buttonResetTimers.get(button);
    if (existing) window.clearTimeout(existing);
    button.textContent = label;
    button.classList.add('is-success');
    const timer = window.setTimeout(() => {
        button.textContent = restoreLabel;
        button.classList.remove('is-success');
        buttonResetTimers.delete(button);
    }, duration);
    buttonResetTimers.set(button, timer);
}

function initConfigActions() {
    const container = document.getElementById('configs-container');
    if (!container || container.dataset.actionsReady === 'true') return;
    container.dataset.actionsReady = 'true';
    container.addEventListener('click', async (event) => {
        const button = event.target.closest('[data-config-action]');
        if (!button || !container.contains(button)) return;
        const action = button.dataset.configAction;
        const link = button.dataset.link || '';
        const name = button.dataset.name || t('config');
        if (action === 'copy') {
            const success = await copyToClipboard(link, t('configCopied'));
            if (success) showTemporaryButtonState(button, t('copied'), t('copy'));
        } else if (action === 'qr') {
            showQr(link, name);
        }
    });
}

async function copyToClipboard(text, message) {
    if (!text) return false;
    try {
        if (navigator.clipboard?.writeText) {
            await navigator.clipboard.writeText(text);
        } else {
            fallbackCopy(text);
        }
        showToast(message || t('copied'));
        return true;
    } catch (_) {
        try {
            fallbackCopy(text);
            showToast(message || t('copied'));
            return true;
        } catch (_) {
            return false;
        }
    }
}

function fallbackCopy(text) {
    const area = document.createElement('textarea');
    area.value = text;
    area.readOnly = true;
    area.style.position = 'fixed';
    area.style.insetInlineStart = '-9999px';
    document.body.append(area);
    area.select();
    document.execCommand('copy');
    area.remove();
}

let toastTimer = null;
function showToast(message) {
    const toast = document.getElementById('toast');
    if (!toast) return;
    toast.textContent = message;
    toast.hidden = false;
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => { toast.hidden = true; }, 1900);
}

let activeQrLink = '';
let qrReturnFocus = null;
async function showQr(link, name) {
    const dialog = document.getElementById('qr-dialog');
    const canvas = document.getElementById('qr-canvas');
    if (!dialog || !canvas) return;
    let QrConstructor = globalThis.QRious;
    if (!QrConstructor) {
        try {
            QrConstructor = await globalThis.HyperSentryVendors?.loadQrLibrary();
        } catch (_) {
            showToast(t('qrUnavailable'));
            return;
        }
    }

    activeQrLink = link;
    qrReturnFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const { protocolLabel } = getConfigMeta(link, 0);
    document.getElementById('qr-title').textContent = name;
    const meta = document.getElementById('qr-meta');
    if (meta) meta.textContent = protocolLabel;
    new QrConstructor({ element: canvas, value: link, size: 220, background: '#ffffff', foreground: '#06111d' });
    if (typeof dialog.showModal === 'function') dialog.showModal();
    else dialog.setAttribute('open', '');
    window.requestAnimationFrame(() => document.getElementById('qr-copy')?.focus());
}

function closeQr() {
    const dialog = document.getElementById('qr-dialog');
    if (!dialog) return;
    if (typeof dialog.close === 'function' && dialog.open) dialog.close();
    else dialog.removeAttribute('open');
    activeQrLink = '';
    const returnTarget = qrReturnFocus;
    qrReturnFocus = null;
    if (returnTarget?.isConnected) window.requestAnimationFrame(() => returnTarget.focus());
}

function initActions() {
    const copySubscription = document.getElementById('copy-subscription');
    copySubscription?.addEventListener('click', async () => {
        const success = await copyToClipboard(copySubscription.dataset.subUrl, t('linkCopied'));
        if (success) showTemporaryButtonState(copySubscription, t('copied'), t('copySubscriptionLink'));
    });

    document.getElementById('qr-copy')?.addEventListener('click', async (event) => {
        const success = await copyToClipboard(activeQrLink, t('configCopied'));
        if (success) showTemporaryButtonState(event.currentTarget, t('copied'), t('copyConfig'));
    });
    document.getElementById('qr-close')?.addEventListener('click', closeQr);
    const qrDialog = document.getElementById('qr-dialog');
    qrDialog?.addEventListener('cancel', (event) => {
        event.preventDefault();
        closeQr();
    });
    qrDialog?.addEventListener('click', (event) => {
        if (event.target === qrDialog) closeQr();
    });
    initConfigActions();
}

if (hasDocument) {
    document.addEventListener('DOMContentLoaded', () => {
        initTheme();
        initAvatar();
        initActions();
        initLanguage();
    });
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { I18N, deriveSubscriptionState, getDaysRemaining };
}

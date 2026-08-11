'use strict';

(function initHyperSentryVendors(global) {
    const QRIousIntegrity = 'sha512-pUhApVQtLbnpLtJn6DuzDD5o2xtmLJnJ7oBoMsBnzOkVkpqofGLGPaBJ6ayD2zQe3lCgCibhJBi4cj5wAxwVKA==';
    const sources = Object.freeze([
        'https://cdn.jsdelivr.net/npm/qrious@4.0.2/dist/qrious.min.js',
        'https://cdnjs.cloudflare.com/ajax/libs/qrious/4.0.2/qrious.min.js'
    ]);

    let qrPromise = null;

    function loadScript(url) {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = url;
            script.async = true;
            script.crossOrigin = 'anonymous';
            script.referrerPolicy = 'no-referrer';
            script.integrity = QRIousIntegrity;
            script.addEventListener('load', () => resolve(global.QRious), { once: true });
            script.addEventListener('error', () => {
                script.remove();
                reject(new Error(`Failed to load ${url}`));
            }, { once: true });
            document.head.append(script);
        });
    }

    async function loadQrLibrary() {
        if (global.QRious) return global.QRious;
        if (qrPromise) return qrPromise;

        qrPromise = (async () => {
            let lastError = null;
            for (const source of sources) {
                try {
                    const library = await loadScript(source);
                    if (library) return library;
                } catch (error) {
                    lastError = error;
                }
            }
            qrPromise = null;
            throw lastError || new Error('QR library could not be loaded');
        })();

        return qrPromise;
    }

    global.HyperSentryVendors = Object.freeze({ loadQrLibrary });
})(globalThis);

document.addEventListener('DOMContentLoaded', () => {
    initThemeToggle(); renderConfigs();
    initTrafficStats();
    initDaysStats();
});

function initThemeToggle() {
    const toggleBtn = document.getElementById('theme-toggle');
    if (!toggleBtn) return;

    function applyTheme(isDark) {
        document.body.className = isDark ? 'theme-dark' : 'theme-light';
        localStorage.setItem('neo-sdk-theme', document.body.className);
    }

    const savedTheme = localStorage.getItem('neo-sdk-theme');
    if (savedTheme) {
        applyTheme(savedTheme === 'theme-dark');
    } else {
        const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
        applyTheme(prefersDark);
    }

    toggleBtn.addEventListener('click', () => {
        applyTheme(document.body.className === 'theme-light');
    });
}

function initTrafficStats() {
    const rawData = document.getElementById('raw-data');
    if (!rawData) return;

    const upBytes = parseInt(rawData.getAttribute('data-up') || '0', 10);
    const downBytes = parseInt(rawData.getAttribute('data-down') || '0', 10);
    const totalBytes = parseInt(rawData.getAttribute('data-total') || '0', 10);

    const usedBytes = upBytes + downBytes;
    
    const heroValEl = document.getElementById('hero-rem-val');
    const heroUnitEl = document.getElementById('hero-rem-unit');
    const bar = document.getElementById('progress-bar');
    
    if (totalBytes === 0) {
        if (heroValEl) heroValEl.innerText = "Unlimited";
        if (heroUnitEl) heroUnitEl.innerText = "";
        if (bar) bar.style.width = '100%';
    } else {
        const remBytes = Math.max(0, totalBytes - usedBytes);
        const formatted = formatBytes(remBytes);
        if (heroValEl && heroUnitEl) {
            const parts = formatted.split(' ');
            heroValEl.innerText = parts[0];
            heroUnitEl.innerText = parts[1];
        }
        
        let percentage = (usedBytes / totalBytes) * 100;
        if (percentage > 100) percentage = 100;
        if (bar) {
            setTimeout(() => {
                bar.style.width = percentage + '%';
                if(percentage > 90) bar.style.backgroundColor = 'var(--danger)';
                else if(percentage > 75) bar.style.backgroundColor = 'var(--warning)';
            }, 300);
        }
    }
}

function formatBytes(bytes) {
    if (bytes === 0) return '0.00 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function initDaysStats() {
    const rawData = document.getElementById('raw-data');
    const daysLeftEl = document.getElementById('days-left');
    const advExpiryEl = document.getElementById('adv-expiry');
    if (!rawData) return;

    const expireSeconds = parseInt(rawData.getAttribute('data-expire') || '0', 10);
    
    if (expireSeconds === 0) {
        if(daysLeftEl) daysLeftEl.innerText = "∞";
        if(advExpiryEl) advExpiryEl.innerText = "Unlimited";
        return;
    }

    const expiryDate = new Date(expireSeconds * 1000);
    const now = new Date();
    const diffTime = expiryDate - now;
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if(daysLeftEl) {
        if (diffDays < 0) {
            daysLeftEl.innerText = "0";
            daysLeftEl.style.color = "var(--danger)";
        } else {
            daysLeftEl.innerText = diffDays;
        }
    }
    
    if(advExpiryEl) {
        advExpiryEl.innerText = expiryDate.toLocaleDateString();
    }
}

function copyToClipboard(text, msg) {
    if (!text) return;
    
    var showToast = function() {
        var toast = document.getElementById('toast');
        if (toast) {
            toast.innerText = msg || 'Copied!';
            toast.style.display = 'block';
            toast.style.opacity = '1';
            setTimeout(function() { 
                toast.style.display = 'none'; 
            }, 2000);
        } else if (typeof showNotification === 'function') {
            showNotification(msg || 'Copied!');
        }
    };

    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(showToast).catch(function() {
            fallbackCopy(text, showToast);
        });
    } else {
        fallbackCopy(text, showToast);
    }
}

function fallbackCopy(text, callback) {
    var textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.position = "fixed";
    textArea.style.left = "-9999px";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    try {
        document.execCommand('copy');
        callback();
    } catch (err) {
        console.error('Fallback copy failed', err);
    }
    document.body.removeChild(textArea);
}

function showQR(link, name) {
    const modal = document.getElementById('qr-modal');
    const title = document.getElementById('qr-title');
    const canvas = document.getElementById('qr-canvas');
    if (!modal || !title || !canvas) return;
    
    title.innerText = name;
    new QRious({
        element: canvas,
        value: link,
        size: 200,
        background: 'white',
        foreground: 'black'
    });
    
    modal.classList.add('open');
}
function renderConfigs() {
    var container = document.getElementById('configs-container');
    var rawLinksContainer = document.getElementById('raw-links-container');
    if (!container || !rawLinksContainer) return;

    var rawLinkEls = rawLinksContainer.querySelectorAll('.raw-link');
    var rawLinks = [];
    for (var i = 0; i < rawLinkEls.length; i++) {
        var t = rawLinkEls[i].innerText.trim();
        if (t.length > 0) rawLinks.push(t);
    }
    
    if (rawLinks.length === 0) {
        container.innerHTML = '<div style="text-align:center; padding: 24px; opacity:0.5;">No configs available</div>';
        return;
    }

    var html = '';
    for (var j = 0; j < rawLinks.length; j++) {
        var link = rawLinks[j];
        var name = "Config " + (j + 1);
        var protocol = "vpn";
        try {
            var hashIndex = link.indexOf('#');
            if (hashIndex !== -1) {
                name = decodeURIComponent(link.substring(hashIndex + 1));
            }
            var protoIndex = link.indexOf('://');
            if (protoIndex !== -1) {
                protocol = link.substring(0, protoIndex).toLowerCase();
            }
        } catch (e) {}
        
        var safeName = name.replace(/'/g, "\\'").replace(/"/g, '&quot;');
        var safeLink = link.replace(/'/g, "\\'").replace(/"/g, '&quot;');
        
        html += '<div class="card" style="display: flex; justify-content: space-between; align-items: center; padding: 12px 16px;">';
        html += '<div style="font-weight: 500; font-size: 0.875rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 60%;">' + safeName + '</div>';
        html += '<div style="display: flex; gap: 8px;">';
        html += '<button class="btn btn-small" onclick="copyToClipboard(\'' + safeLink + '\', \'Config Copied!\')">Copy</button>';
        html += '<button class="btn btn-small btn-primary" onclick="showQR(\'' + safeLink + '\', \'' + safeName + '\')">QR</button>';
        html += '</div></div>';
    }
    container.innerHTML = html;
}

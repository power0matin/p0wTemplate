const fs = require('fs');
const path = require('path');

const themesDir = path.join(__dirname, 'themes');
const themes = ['neo-dashboard', 'neo-default', 'neo-eclipse', 'neo-glass', 'neo-minimal', 'neo-vibrant'];

themes.forEach(theme => {
    const indexPath = path.join(themesDir, theme, 'index.html');
    if (!fs.existsSync(indexPath)) return;
    
    let html = fs.readFileSync(indexPath, 'utf8');

    // 1. Fix Brand Name (Replace hardcoded theme names with {{ .subTitle }})
    if (theme === 'neo-default') {
        html = html.replace('<h1 class="logo">Neo Default</h1>', '<h1 class="logo">{{ .subTitle }}</h1>');
        html = html.replace('{{ .client.Email }}', '{{ .emails }}');
    } else if (theme === 'neo-glass') {
        html = html.replace('<h1 class="glass-title">Neo Glass</h1>', '<h1 class="glass-title">{{ .subTitle }}</h1>');
        html = html.replace('<span id="display-name">{{ .subTitle }}</span>', '<span id="display-name">{{ .emails }}</span>');
    } else if (theme === 'neo-eclipse') {
        html = html.replace('<div class="greeting">Hi, <span id="display-name">{{ .email }}</span></div>', '<div class="greeting">Hi, <span id="display-name">{{ .emails }}</span></div>');
        // Add brand title to eclipse header
        if (!html.includes('class="brand-title"')) {
            html = html.replace('<header class="header-pill">', '<header class="header-pill">\n            <div class="brand-title" style="position:absolute; top:-30px; left:0; font-size:1.5rem; font-weight:700;">{{ .subTitle }}</div>');
        }
    } else if (theme === 'neo-vibrant') {
        html = html.replace('<h2 style="margin:0; font-size: 1rem;" id="display-name">{{ .subTitle }}</h2>', '<h2 style="margin:0; font-size: 1rem;" id="display-name">{{ .emails }}</h2>');
        if (!html.includes('class="brand-title"')) {
            html = html.replace('<header class="header">', '<header class="header">\n            <h1 class="brand-title" style="font-size:1.25rem; font-weight:700; color:var(--text-primary); margin:0;">{{ .subTitle }}</h1>');
        }
    } else if (theme === 'neo-minimal') {
        html = html.replace('{{ .client.Email }}', '{{ .emails }}');
        html = html.replace('<h1 class="logo">Neo Minimal</h1>', '<h1 class="logo">{{ .subTitle }}</h1>');
    } else if (theme === 'neo-dashboard') {
        html = html.replace('{{ .email }}', '{{ .emails }}');
        html = html.replace('<div class="sidebar-logo">Neo Dash</div>', '<div class="sidebar-logo">{{ .subTitle }}</div>');
    }

    // 2. Add Support Button
    const supportBtn = `
            <a class="modal-btn" style="text-decoration:none; background: var(--success); color: white; margin-top: 12px;" href="{{ .subSupportUrl }}" target="_blank">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>
                Contact Support
            </a>`;
            
    if (html.includes('<!-- Action Modal -->') || html.includes('Quick Actions Modal')) {
        if (!html.includes('{{ .subSupportUrl }}')) {
            // Find the last </a> or </button> inside the modal to insert after
            html = html.replace(/(Import to Shadowrocket \/ iOS\s*<\/a>)/i, '$1' + supportBtn);
        }
    } else if (html.includes('Help & Support')) {
         if (!html.includes('{{ .subSupportUrl }}')) {
            html = html.replace(/<p style="margin-top:8px;">Import this link[^<]+<\/p>/, '$&\n<a href="{{ .subSupportUrl }}" style="display:block; margin-top:12px; color:var(--primary); font-weight:600; text-decoration:none;" target="_blank">Contact Support &rarr;</a>');
         }
    }

    fs.writeFileSync(indexPath, html);
    
    // Update app.js for lastOnline relative time
    const appJsPath = path.join(themesDir, theme, 'assets', 'js', 'app.js');
    if (fs.existsSync(appJsPath)) {
        let appJs = fs.readFileSync(appJsPath, 'utf8');
        
        // Add relative time function if not exists
        if (!appJs.includes('function timeAgo')) {
            const timeAgoFunc = `
function timeAgo(date) {
    const seconds = Math.floor((new Date() - date) / 1000);
    let interval = Math.floor(seconds / 31536000);
    if (interval > 1) return interval + " years ago";
    interval = Math.floor(seconds / 2592000);
    if (interval > 1) return interval + " months ago";
    interval = Math.floor(seconds / 86400);
    if (interval > 1) return interval + " days ago";
    interval = Math.floor(seconds / 3600);
    if (interval >= 1) return interval + " hours ago";
    interval = Math.floor(seconds / 60);
    if (interval >= 1) return interval + " minutes ago";
    return Math.floor(seconds) + " seconds ago";
}
`;
            appJs = appJs + timeAgoFunc;
        }

        // Update relative time in initDateTimeFormatting
        if (appJs.includes('el.innerText = `${m}/${day}/${y}, ${hr}:${min}:${sec}`;')) {
            appJs = appJs.replace(
                'el.innerText = `${m}/${day}/${y}, ${hr}:${min}:${sec}`;', 
                'el.innerText = el.parentElement.innerText.includes("Last Online") ? timeAgo(d) : `${m}/${day}/${y}, ${hr}:${min}:${sec}`;'
            );
        }

        fs.writeFileSync(appJsPath, appJs);
    }
});

console.log('Themes updated successfully with user requests!');

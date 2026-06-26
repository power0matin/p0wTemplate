const fs = require('fs');
const path = require('path');

const themesDir = path.join(__dirname, 'themes');
const buildDir = path.join(__dirname, 'build_temp');

if (fs.existsSync(buildDir)) {
    fs.rmSync(buildDir, { recursive: true, force: true });
}
fs.mkdirSync(buildDir);

const themes = ['neo-dashboard', 'neo-default', 'neo-eclipse', 'neo-glass', 'neo-minimal', 'neo-vibrant'];

themes.forEach(theme => {
    const themePath = path.join(themesDir, theme);
    if (!fs.existsSync(themePath)) return;
    
    const themeBuildPath = path.join(buildDir, theme);
    fs.mkdirSync(themeBuildPath);
    
    // Copy all files first
    function copyRecursiveSync(src, dest) {
        const exists = fs.existsSync(src);
        const stats = exists && fs.statSync(src);
        const isDirectory = exists && stats.isDirectory();
        if (isDirectory) {
            if (!fs.existsSync(dest)) fs.mkdirSync(dest);
            fs.readdirSync(src).forEach(function(childItemName) {
                copyRecursiveSync(path.join(src, childItemName), path.join(dest, childItemName));
            });
        } else {
            fs.copyFileSync(src, dest);
        }
    }
    
    copyRecursiveSync(themePath, themeBuildPath);
    
    // Inline CSS and JS in HTML files
    ['index.html', 'sub.html'].forEach(htmlFile => {
        const htmlPath = path.join(themeBuildPath, htmlFile);
        if (!fs.existsSync(htmlPath)) return;
        
        let htmlContent = fs.readFileSync(htmlPath, 'utf8');
        
        // Inline CSS
        htmlContent = htmlContent.replace(/<link\s+rel=["']stylesheet["']\s+href=["']([^"']+)["']\s*\/?>/gi, (match, href) => {
            const cssPath = path.join(themeBuildPath, href);
            if (fs.existsSync(cssPath)) {
                const cssContent = fs.readFileSync(cssPath, 'utf8');
                return `<style>\n${cssContent}\n</style>`;
            }
            return match;
        });
        
        // Inline JS
        htmlContent = htmlContent.replace(/<script\s+src=["']([^"']+)["']><\/script>/gi, (match, src) => {
            // Ignore external URLs
            if (src.startsWith('http')) return match;
            
            const jsPath = path.join(themeBuildPath, src);
            if (fs.existsSync(jsPath)) {
                const jsContent = fs.readFileSync(jsPath, 'utf8');
                return `<script>\n${jsContent}\n</script>`;
            }
            return match;
        });
        
        fs.writeFileSync(htmlPath, htmlContent);
    });
    
    // Remove assets directory from build since it's inlined
    const assetsDir = path.join(themeBuildPath, 'assets');
    if (fs.existsSync(assetsDir)) {
        fs.rmSync(assetsDir, { recursive: true, force: true });
    }
});

console.log('Inlining completed!');

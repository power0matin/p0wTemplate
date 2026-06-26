const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

const themesDir = path.join(__dirname, 'themes');
const packagesDir = path.join(__dirname, 'packages');

if (!fs.existsSync(packagesDir)) {
    fs.mkdirSync(packagesDir);
}

const themes = ['neo-dashboard', 'neo-default', 'neo-eclipse', 'neo-glass', 'neo-minimal', 'neo-vibrant'];

themes.forEach(theme => {
    const themePath = path.join(themesDir, theme);
    if (!fs.existsSync(themePath)) return;
    
    const output = fs.createWriteStream(path.join(packagesDir, `${theme}.zip`));
    const archive = archiver('zip', { zlib: { level: 9 } });
    
    output.on('close', function() {
        console.log(`${theme}.zip created successfully: ${archive.pointer()} total bytes`);
    });
    
    archive.on('error', function(err) {
        throw err;
    });
    
    archive.pipe(output);
    archive.directory(themePath, false); // false means don't put the directory itself, just contents
    archive.finalize();
});

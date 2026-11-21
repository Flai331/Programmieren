// Kopiert die Web-App (../web) in die Desktop-App – keine doppelte Pflege.
const fs = require('fs');
const path = require('path');
const src = path.join(__dirname, '..', 'web');
const dst = path.join(__dirname, 'web');
fs.rmSync(dst, { recursive: true, force: true });
fs.cpSync(src, dst, { recursive: true });
console.log('Web-App kopiert nach', dst);

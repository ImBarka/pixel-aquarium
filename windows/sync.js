// Menyalin aquarium.html dari root repo agar versi Mac dan Windows memakai satu sumber gambar.
const fs = require('fs');
const path = require('path');
fs.copyFileSync(path.join(__dirname, '..', 'aquarium.html'), path.join(__dirname, 'aquarium.html'));
console.log('aquarium.html disalin dari root repo');

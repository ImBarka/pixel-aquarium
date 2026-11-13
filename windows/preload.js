// Menangani seret jendela, klik 2x (beri makan), dan klik kanan (menu) dari halaman.
const { ipcRenderer } = require('electron');

window.addEventListener('DOMContentLoaded', () => {
  let drag = null;
  document.addEventListener('mousedown', e => {
    if (e.button !== 0) return;
    drag = { sx: e.screenX, sy: e.screenY };
    ipcRenderer.send('drag-start');
  });
  window.addEventListener('mousemove', e => {
    if (drag) ipcRenderer.send('drag-move', e.screenX - drag.sx, e.screenY - drag.sy);
  });
  window.addEventListener('mouseup', () => {
    if (drag) { drag = null; ipcRenderer.send('drag-end'); }
  });
  document.addEventListener('dblclick', () => ipcRenderer.send('feed'));
  document.addEventListener('contextmenu', e => { e.preventDefault(); ipcRenderer.send('menu'); });
});

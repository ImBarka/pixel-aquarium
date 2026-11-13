// PixelAquarium untuk Windows (Electron).
// Jendela tanpa bingkai, transparan, bisa diseret, dengan menu di system tray.
const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain, screen } = require('electron');
const path = require('path');
const fs = require('fs');

const BASE_W = 128, BASE_H = 80;
const cfgPath = path.join(app.getPath('userData'), 'settings.json');
let cfg = { onTop: true, scale: 3, cycle: 'real', x: null, y: null };
try { cfg = { ...cfg, ...JSON.parse(fs.readFileSync(cfgPath, 'utf8')) }; } catch { /* pakai default */ }
const save = () => { try { fs.writeFileSync(cfgPath, JSON.stringify(cfg)); } catch { /* abaikan */ } };

if (!app.requestSingleInstanceLock()) { app.quit(); }

let win = null, tray = null, dragOrigin = null;

function js(code) { if (win) win.webContents.executeJavaScript(code).catch(() => {}); }

function createWindow() {
  const w = BASE_W * cfg.scale, h = BASE_H * cfg.scale;
  const wa = screen.getPrimaryDisplay().workArea;
  const x = cfg.x ?? wa.x + wa.width - w - 24;
  const y = cfg.y ?? wa.y + wa.height - h - 24;

  win = new BrowserWindow({
    width: w, height: h, x, y,
    frame: false, transparent: true, hasShadow: false,
    resizable: false, maximizable: false, minimizable: false, fullscreenable: false,
    skipTaskbar: true, show: false, alwaysOnTop: cfg.onTop,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, backgroundThrottling: false },
  });
  if (cfg.onTop) win.setAlwaysOnTop(true, 'screen-saver');
  win.setMenu(null);
  win.loadFile(path.join(__dirname, 'aquarium.html'));
  win.webContents.on('did-finish-load', () => { js(`window.setCycle('${cfg.cycle}')`); win.show(); });
}

function applyBounds() {
  const [x, y] = win.getPosition();
  win.setBounds({ x, y, width: BASE_W * cfg.scale, height: BASE_H * cfg.scale });
}

function buildMenu() {
  const radio = (label, checked, click) => ({ label, type: 'radio', checked, click });
  return Menu.buildFromTemplate([
    { label: 'Selalu di atas jendela', type: 'checkbox', checked: cfg.onTop, click: it => {
        cfg.onTop = it.checked; win.setAlwaysOnTop(cfg.onTop, cfg.onTop ? 'screen-saver' : 'normal'); save(); refresh(); } },
    { type: 'separator' },
    { label: 'Ukuran', submenu: [
        radio('Kecil (2×)', cfg.scale === 2, () => { cfg.scale = 2; applyBounds(); save(); refresh(); }),
        radio('Sedang (3×)', cfg.scale === 3, () => { cfg.scale = 3; applyBounds(); save(); refresh(); }),
        radio('Besar (4×)', cfg.scale === 4, () => { cfg.scale = 4; applyBounds(); save(); refresh(); }),
    ] },
    { label: 'Siklus siang-malam', submenu: [
        radio('Waktu nyata (sesuai jam PC)', cfg.cycle === 'real', () => { cfg.cycle = 'real'; js("window.setCycle('real')"); save(); }),
        radio('Dipercepat (1 hari = 4 menit)', cfg.cycle === 'fast', () => { cfg.cycle = 'fast'; js("window.setCycle('fast')"); save(); }),
        radio('Siang terus', cfg.cycle === 'day', () => { cfg.cycle = 'day'; js("window.setCycle('day')"); save(); }),
        radio('Malam terus', cfg.cycle === 'night', () => { cfg.cycle = 'night'; js("window.setCycle('night')"); save(); }),
    ] },
    { label: 'Panggil hiu atau penyu', click: () => js('window.spawn && window.spawn()') },
    { label: 'Beri makan ikan (klik 2×)', click: () => js('window.feed && window.feed()') },
    { label: win && win.isVisible() ? 'Sembunyikan akuarium' : 'Tampilkan akuarium', click: () => {
        if (win.isVisible()) { win.hide(); js('window.setPaused && window.setPaused(true)'); }
        else { win.show(); js('window.setPaused && window.setPaused(false)'); }
        refresh(); } },
    { label: 'Buka saat Windows menyala', type: 'checkbox', checked: app.getLoginItemSettings().openAtLogin,
      click: it => app.setLoginItemSettings({ openAtLogin: it.checked }) },
    { type: 'separator' },
    { label: 'Keluar', click: () => app.quit() },
  ]);
}

function refresh() { if (tray) tray.setContextMenu(buildMenu()); }

app.whenReady().then(() => {
  createWindow();
  const icon = nativeImage.createFromPath(path.join(__dirname, 'assets', 'icon.png')).resize({ width: 16, height: 16 });
  tray = new Tray(icon);
  tray.setToolTip('PixelAquarium');
  tray.on('click', () => tray.popUpContextMenu(buildMenu()));
  refresh();
});

ipcMain.on('drag-start', () => { if (win) dragOrigin = win.getPosition(); });
ipcMain.on('drag-move', (_e, dx, dy) => {
  if (!win || !dragOrigin) return;
  win.setBounds({ x: Math.round(dragOrigin[0] + dx), y: Math.round(dragOrigin[1] + dy), width: BASE_W * cfg.scale, height: BASE_H * cfg.scale });
});
ipcMain.on('drag-end', () => { if (win) { [cfg.x, cfg.y] = win.getPosition(); save(); } dragOrigin = null; });
ipcMain.on('feed', () => js('window.feed && window.feed()'));
ipcMain.on('menu', () => { if (win) buildMenu().popup({ window: win }); });

app.on('window-all-closed', () => { /* tetap hidup di tray */ });

#!/usr/bin/env gjs
imports.gi.versions.Gtk = '3.0';
const { Gtk, Gdk, GLib, GdkPixbuf, Pango } = imports.gi;

const HOME = GLib.get_home_dir();
const I3 = HOME + '/.config/i3';
const CSS_FILE = I3 + '/control-center.css';
const ART_PATH = '/tmp/control-center-art';
const BAR_HEIGHT = 34;

function sh(cmd) {
  try {
    let [ok, out] = GLib.spawn_command_line_sync(cmd);
    if (!ok || !out) return '';
    return new TextDecoder().decode(out).trim();
  } catch (e) { return ''; }
}
function shAsync(cmd) { try { GLib.spawn_command_line_async(cmd); } catch (e) {} }

function getVolume() {
  let s = sh('wpctl get-volume @DEFAULT_AUDIO_SINK@');
  let m = s.match(/Volume:\s*([0-9.]+)/);
  return { vol: m ? parseFloat(m[1]) : 0, muted: /MUTED/.test(s) };
}
function getWifi() {
  let on = sh('nmcli radio wifi') === 'enabled';
  let ssid = '';
  if (on) ssid = sh("sh -c \"nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2-\"");
  return { on, ssid: on ? (ssid || '未连接') : '关' };
}
function getBt() {
  let s = sh('rfkill list bluetooth');
  return { on: s.length > 0 && /Soft blocked:\s*no/.test(s) };
}
function getPlayer() {
  let status = sh('playerctl status');
  if (status === '' || status === 'No players found') return { ok: false };
  let meta = sh("playerctl metadata --format '{{title}}\\t{{artist}}\\t{{mpris:artUrl}}'");
  let f = meta.split('\t');
  return { ok: true, status, title: f[0] || 'Unknown', artist: f[1] || '', artUrl: f[2] || '' };
}

let lastArtUrl = null;
function ensureArt(url) {
  if (!url) { lastArtUrl = null; return null; }
  if (url.startsWith('file://')) {
    let p = decodeURIComponent(url.slice(7));
    return GLib.file_test(p, GLib.FileTest.EXISTS) ? p : null;
  }
  if (url !== lastArtUrl) { sh('curl -sL --max-time 5 -o ' + ART_PATH + ' ' + GLib.shell_quote(url)); lastArtUrl = url; }
  return GLib.file_test(ART_PATH, GLib.FileTest.EXISTS) ? ART_PATH : null;
}

let win, volScale, volSeeking = false, lastArtSig = null;
let lblTitle, lblArtist, imgArt, artBox, btnPlay;
let wifiTile, wifiIcon, wifiSub, btTile, btIcon, btSub, spkBtn;
let pendingPower = null, pendingTimer = 0, rebootBtn, shutBtn;

Gtk.init(null);

let provider = new Gtk.CssProvider();
try { provider.load_from_path(CSS_FILE); } catch (e) { logError(e); }
Gtk.StyleContext.add_provider_for_screen(
  Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);

win = new Gtk.Window({ type: Gtk.WindowType.TOPLEVEL });
win.set_decorated(false);
win.set_resizable(false);
win.set_skip_taskbar_hint(true);
win.set_skip_pager_hint(true);
win.set_keep_above(true);
win.set_type_hint(Gdk.WindowTypeHint.UTILITY);
win.set_app_paintable(true);
win.get_style_context().add_class('cc-window');
let rgba = Gdk.Screen.get_default().get_rgba_visual();
if (rgba) win.set_visual(rgba);

let panel = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12 });
panel.get_style_context().add_class('cc-panel');
panel.set_size_request(300, -1);
win.add(panel);

// now playing
let npTile = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 12 });
npTile.get_style_context().add_class('np-tile');
imgArt = new Gtk.Image();
artBox = new Gtk.Box();
artBox.get_style_context().add_class('art');
artBox.add(imgArt);
let npInfo = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL });
npInfo.set_valign(Gtk.Align.CENTER);
lblTitle = new Gtk.Label({ label: '' }); lblTitle.get_style_context().add_class('np-title');
lblTitle.set_ellipsize(Pango.EllipsizeMode.END); lblTitle.set_xalign(0);
lblArtist = new Gtk.Label({ label: '' }); lblArtist.get_style_context().add_class('np-artist');
lblArtist.set_ellipsize(Pango.EllipsizeMode.END); lblArtist.set_xalign(0);
npInfo.pack_start(lblTitle, false, false, 0);
npInfo.pack_start(lblArtist, false, false, 0);
function npBtn(label, cb) {
  let b = new Gtk.Button({ label }); b.get_style_context().add_class('np-ctl');
  b.set_relief(Gtk.ReliefStyle.NONE); b.connect('clicked', cb); return b;
}
let npCtl = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 10 });
npCtl.set_valign(Gtk.Align.CENTER);
btnPlay = npBtn('⏯', () => shAsync('playerctl play-pause'));
npCtl.pack_start(npBtn('⏮', () => shAsync('playerctl previous')), false, false, 0);
npCtl.pack_start(btnPlay, false, false, 0);
npCtl.pack_start(npBtn('⏭', () => shAsync('playerctl next')), false, false, 0);
npTile.pack_start(artBox, false, false, 0);
npTile.pack_start(npInfo, true, true, 0);
npTile.pack_end(npCtl, false, false, 0);
panel.pack_start(npTile, false, false, 0);

// WiFi tile: build with SSID in its own EventBox up front (independent click zone)
function makeWifiTile() {
  let eb = new Gtk.EventBox();
  let box = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 10 });
  box.get_style_context().add_class('tile');
  let icon = new Gtk.Label({ label: '' }); icon.get_style_context().add_class('tile-icon');
  let col = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL }); col.set_valign(Gtk.Align.CENTER);
  let title = new Gtk.Label({ label: 'WiFi' }); title.get_style_context().add_class('tile-title'); title.set_xalign(0);
  let sub = new Gtk.Label({ label: '' }); sub.get_style_context().add_class('tile-sub'); sub.set_xalign(0);
  let ssidEb = new Gtk.EventBox(); ssidEb.add(sub);
  col.pack_start(title, false, false, 0);
  col.pack_start(ssidEb, false, false, 0);
  box.pack_start(icon, false, false, 0);
  box.pack_start(col, true, true, 0);
  eb.add(box);
  ssidEb.connect('button-press-event', () => {
    shAsync('setsid bash ' + I3 + '/rofi-wifi-menu.sh');
    Gtk.main_quit(); return true;     // consume: don't bubble to tile toggle
  });
  eb.connect('button-press-event', () => {
    let cur = getWifi();
    shAsync('nmcli radio wifi ' + (cur.on ? 'off' : 'on'));
    return false;
  });
  return { eb, box, icon, sub };
}
function makeToggleTile(titleText, onClick) {
  let eb = new Gtk.EventBox();
  let box = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 10 });
  box.get_style_context().add_class('tile');
  let icon = new Gtk.Label({ label: '' }); icon.get_style_context().add_class('tile-icon');
  let col = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL }); col.set_valign(Gtk.Align.CENTER);
  let title = new Gtk.Label({ label: titleText }); title.get_style_context().add_class('tile-title'); title.set_xalign(0);
  let sub = new Gtk.Label({ label: '' }); sub.get_style_context().add_class('tile-sub'); sub.set_xalign(0);
  col.pack_start(title, false, false, 0);
  col.pack_start(sub, false, false, 0);
  box.pack_start(icon, false, false, 0);
  box.pack_start(col, true, true, 0);
  eb.add(box);
  eb.connect('button-press-event', onClick);
  return { eb, box, icon, sub };
}
function setTileOn(box, icon, on) {
  let c = box.get_style_context(), ic = icon.get_style_context();
  if (on) { c.add_class('tile-on'); ic.add_class('tile-icon-on'); ic.remove_class('tile-icon'); }
  else { c.remove_class('tile-on'); ic.add_class('tile-icon'); ic.remove_class('tile-icon-on'); }
}

let connRow = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 12, homogeneous: true });
let wt = makeWifiTile(); wifiTile = wt.box; wifiIcon = wt.icon; wifiSub = wt.sub;
let bt = makeToggleTile('蓝牙', () => { let c = getBt(); shAsync('rfkill ' + (c.on ? 'block' : 'unblock') + ' bluetooth'); return false; });
btTile = bt.box; btIcon = bt.icon; btSub = bt.sub;
connRow.pack_start(wt.eb, true, true, 0);
connRow.pack_start(bt.eb, true, true, 0);
panel.pack_start(connRow, false, false, 0);

// volume
let volRow = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 8 });
spkBtn = new Gtk.Button({ label: '󰕾' });
spkBtn.get_style_context().add_class('spk-btn'); spkBtn.set_relief(Gtk.ReliefStyle.NONE);
spkBtn.connect('clicked', () => shAsync('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'));
volScale = new Gtk.Scale({ orientation: Gtk.Orientation.HORIZONTAL });
volScale.get_style_context().add_class('vol-scale');
volScale.set_draw_value(false); volScale.set_range(0, 1); volScale.set_hexpand(true);
volScale.connect('button-press-event', () => { volSeeking = true; return false; });
volScale.connect('button-release-event', () => {
  shAsync('wpctl set-volume @DEFAULT_AUDIO_SINK@ ' + volScale.get_value().toFixed(2));
  volSeeking = false; return false;
});
volRow.pack_start(spkBtn, false, false, 0);
volRow.pack_start(volScale, true, true, 0);
panel.pack_start(volRow, false, false, 0);

// power
function resetPending() {
  if (pendingTimer) { GLib.source_remove(pendingTimer); pendingTimer = 0; }
  pendingPower = null;
  rebootBtn.set_label('󰜉'); rebootBtn.get_style_context().remove_class('pwr-confirm');
  shutBtn.set_label('󰐥'); shutBtn.get_style_context().remove_class('pwr-confirm');
  shutBtn.get_style_context().add_class('pwr-danger');
}
function powerBtn(icon, cls) {
  let b = new Gtk.Button({ label: icon });
  b.get_style_context().add_class('pwr-btn');
  if (cls) b.get_style_context().add_class(cls);
  b.set_relief(Gtk.ReliefStyle.NONE); b.set_hexpand(true);
  return b;
}
function armConfirm(which, btn, action) {
  if (pendingPower === which) { shAsync(action); Gtk.main_quit(); return; }
  resetPending();
  pendingPower = which;
  btn.set_label('确认?'); btn.get_style_context().add_class('pwr-confirm');
  btn.get_style_context().remove_class('pwr-danger');
  pendingTimer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 3, () => { pendingTimer = 0; resetPending(); return GLib.SOURCE_REMOVE; });
}
let pwrRow = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 12, homogeneous: true });
let lockBtn = powerBtn('󰌾', null);
lockBtn.connect('clicked', () => { shAsync('bash ' + I3 + '/lock-screen.sh'); Gtk.main_quit(); });
rebootBtn = powerBtn('󰜉', null);
rebootBtn.connect('clicked', () => armConfirm('reboot', rebootBtn, 'systemctl reboot'));
shutBtn = powerBtn('󰐥', 'pwr-danger');
shutBtn.connect('clicked', () => armConfirm('shutdown', shutBtn, 'systemctl poweroff'));
pwrRow.pack_start(lockBtn, true, true, 0);
pwrRow.pack_start(rebootBtn, true, true, 0);
pwrRow.pack_start(shutBtn, true, true, 0);
panel.pack_start(pwrRow, false, false, 0);

function positionWindow() {
  let display = Gdk.Display.get_default();
  let monitor = display.get_primary_monitor() || display.get_monitor(0);
  let geo = monitor.get_geometry();
  let [w, h] = win.get_size();
  win.move(geo.x + Math.floor((geo.width - w) / 2), geo.y + BAR_HEIGHT + 6);
}

function refresh() {
  let v = getVolume();
  if (!volSeeking) volScale.set_value(Math.min(1, v.vol));
  spkBtn.set_label(v.muted ? '󰝟' : '󰕾');
  let w = getWifi();
  setTileOn(wifiTile, wifiIcon, w.on);
  wifiIcon.set_text(w.on ? '󰖩' : '󰖪');
  wifiSub.set_text(w.ssid);
  let b = getBt();
  setTileOn(btTile, btIcon, b.on);
  btIcon.set_text(b.on ? '󰂯' : '󰂲');
  btSub.set_text(b.on ? '开' : '关');
  let p = getPlayer();
  if (!p.ok) {
    lblTitle.set_text('无播放中'); lblArtist.set_text('');
    btnPlay.set_label('⏯'); imgArt.clear();
    artBox.get_style_context().add_class('art-fallback'); artBox.set_size_request(46, 46);
  } else {
    lblTitle.set_text(p.title); lblArtist.set_text(p.artist);
    btnPlay.set_label(p.status === 'Playing' ? '⏸' : '▶');
    let artFile = ensureArt(p.artUrl);
    let sig = artFile || '';
    if (sig !== lastArtSig) {
      lastArtSig = sig;
      if (artFile) {
        try {
          let pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(artFile, 46, 46, true);
          imgArt.set_from_pixbuf(pb);
          artBox.get_style_context().remove_class('art-fallback');
        } catch (e) { imgArt.clear(); artBox.set_size_request(46, 46); artBox.get_style_context().add_class('art-fallback'); }
      } else { imgArt.clear(); artBox.set_size_request(46, 46); artBox.get_style_context().add_class('art-fallback'); }
    }
  }
  return GLib.SOURCE_CONTINUE;
}

win.connect('focus-out-event', () => { Gtk.main_quit(); return false; });
win.connect('key-press-event', (w, ev) => {
  let [ok, keyval] = ev.get_keyval();
  if (ok && keyval === Gdk.KEY_Escape) Gtk.main_quit();
  return false;
});
win.connect('destroy', () => Gtk.main_quit());

// 先填内容、先定位,再显示 —— 避免窗口在屏幕正中先闪一个空白框
refresh();
{
  let [, nat] = win.get_preferred_size();
  let display = Gdk.Display.get_default();
  let monitor = display.get_primary_monitor() || display.get_monitor(0);
  let geo = monitor.get_geometry();
  win.move(geo.x + Math.floor((geo.width - nat.width) / 2), geo.y + BAR_HEIGHT + 6);
}
win.show_all();
positionWindow();
GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => refresh());
Gtk.main();

#!/usr/bin/env gjs
imports.gi.versions.Gtk = '3.0';
const { Gtk, Gdk, GLib, GdkPixbuf, Pango } = imports.gi;

const HOME = GLib.get_home_dir();
const I3 = HOME + '/.config/i3';
const CSS_FILE = I3 + '/music-panel.css';
const SKIN_FILE = I3 + '/.music-panel-skin';
const ART_PATH = '/tmp/music-panel-art';
const SKINS = ['a', 'b', 'c'];
const BAR_HEIGHT = 34;

function sh(cmd) {
  try {
    let [ok, out] = GLib.spawn_command_line_sync(cmd);
    if (!ok || !out) return '';
    return new TextDecoder().decode(out).trim();
  } catch (e) { return ''; }
}
function shAsync(cmd) {
  try { GLib.spawn_command_line_async(cmd); } catch (e) {}
}

function readSkin() {
  try {
    if (GLib.file_test(SKIN_FILE, GLib.FileTest.EXISTS)) {
      let [ok, data] = GLib.file_get_contents(SKIN_FILE);
      if (ok) {
        let s = new TextDecoder().decode(data).trim();
        if (SKINS.includes(s)) return s;
      }
    }
  } catch (e) {}
  return 'a';
}
function writeSkin(s) {
  try { GLib.file_set_contents(SKIN_FILE, s); } catch (e) {}
}

function getData() {
  let status = sh('playerctl status');
  if (status === '' || status === 'No players found') return { ok: false };
  let meta = sh("playerctl metadata --format " +
    "'{{title}}\\t{{artist}}\\t{{album}}\\t{{mpris:length}}\\t{{mpris:artUrl}}\\t{{shuffle}}\\t{{loop}}'");
  let f = meta.split('\t');
  let lengthUs = parseInt(f[3] || '0', 10) || 0;
  let posSec = parseFloat(sh('playerctl position') || '0') || 0;
  return {
    ok: true, status: status,
    title: f[0] || 'Unknown', artist: f[1] || '', album: f[2] || '',
    lengthSec: lengthUs / 1000000, posSec: posSec,
    artUrl: f[4] || '', shuffle: (f[5] || '').toLowerCase() === 'true', loop: f[6] || 'None',
  };
}

function fmtTime(sec) {
  sec = Math.max(0, Math.floor(sec));
  let m = Math.floor(sec / 60), s = sec % 60;
  return m + ':' + (s < 10 ? '0' : '') + s;
}

let lastArtUrl = null;
function ensureArt(url) {
  if (!url) { lastArtUrl = null; return null; }
  if (url.startsWith('file://')) {
    let p = decodeURIComponent(url.slice(7));
    return GLib.file_test(p, GLib.FileTest.EXISTS) ? p : null;
  }
  if (url !== lastArtUrl) {
    sh("curl -sL --max-time 5 -o " + ART_PATH + " " + GLib.shell_quote(url));
    lastArtUrl = url;
  }
  return GLib.file_test(ART_PATH, GLib.FileTest.EXISTS) ? ART_PATH : null;
}

let skin = readSkin();
let win, scrub, userSeeking = false;
let lblTitle, lblArtist, lblCur, lblRem, imgArt, artBox, btnPlay;

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
win.get_style_context().add_class('music-window');
let rgba = Gdk.Screen.get_default().get_rgba_visual();
if (rgba) win.set_visual(rgba);

let outer = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL });
win.add(outer);

function makeCtlButton(label, cls, cb) {
  let b = new Gtk.Button({ label: label });
  b.get_style_context().add_class('ctl-btn');
  if (cls) b.get_style_context().add_class(cls);
  b.set_relief(Gtk.ReliefStyle.NONE);
  b.connect('clicked', cb);
  return b;
}
function makeScrub() {
  let s = new Gtk.Scale({ orientation: Gtk.Orientation.HORIZONTAL });
  s.get_style_context().add_class('scrub');
  s.set_draw_value(false);
  s.set_range(0, 1);
  s.set_hexpand(true);
  s.connect('button-press-event', () => { userSeeking = true; return false; });
  s.connect('button-release-event', () => {
    shAsync('playerctl position ' + Math.floor(s.get_value()));
    userSeeking = false; return false;
  });
  return s;
}
function makeSkinButton() {
  let b = new Gtk.Button({ label: '◑ ' + skin.toUpperCase() });
  b.get_style_context().add_class('skin-btn');
  b.set_relief(Gtk.ReliefStyle.NONE);
  b.connect('clicked', () => {
    let i = SKINS.indexOf(skin);
    skin = SKINS[(i + 1) % SKINS.length];
    writeSkin(skin);
    buildLayout();
    refresh(true);
  });
  return b;
}

function buildLayout() {
  outer.foreach((c) => outer.remove(c));

  let card = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL });
  card.get_style_context().add_class('card');
  card.get_style_context().add_class('skin-' + skin);

  imgArt = new Gtk.Image();
  artBox = new Gtk.Box();
  artBox.get_style_context().add_class('art');
  artBox.add(imgArt);

  lblTitle = new Gtk.Label({ label: '' });
  lblTitle.get_style_context().add_class('title');
  lblTitle.set_ellipsize(Pango.EllipsizeMode.END);
  lblArtist = new Gtk.Label({ label: '' });
  lblArtist.get_style_context().add_class('artist');
  lblArtist.set_ellipsize(Pango.EllipsizeMode.END);
  lblCur = new Gtk.Label({ label: '0:00' });
  lblCur.get_style_context().add_class('time');
  lblRem = new Gtk.Label({ label: '0:00' });
  lblRem.get_style_context().add_class('time');
  scrub = makeScrub();

  let prev = makeCtlButton('⏮', null, () => shAsync('playerctl previous'));
  btnPlay  = makeCtlButton('⏯', 'ctl-play', () => shAsync('playerctl play-pause'));
  let next = makeCtlButton('⏭', null, () => shAsync('playerctl next'));
  let shuf = makeCtlButton('🔀', null, () => shAsync('playerctl shuffle toggle'));
  let loop = makeCtlButton('🔁', null, () => {
    let cur = sh('playerctl loop');
    let nextLoop = cur === 'None' ? 'Track' : (cur === 'Track' ? 'Playlist' : 'None');
    shAsync('playerctl loop ' + nextLoop);
  });
  let skinBtn = makeSkinButton();

  let timeRow = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL });
  lblCur.set_halign(Gtk.Align.START);
  lblRem.set_halign(Gtk.Align.END); lblRem.set_hexpand(true);
  timeRow.pack_start(lblCur, false, false, 0);
  timeRow.pack_start(lblRem, true, true, 0);

  let ctlRow = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 14 });
  ctlRow.set_halign(Gtk.Align.CENTER);

  let topRow = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL });
  topRow.pack_end(skinBtn, false, false, 0);

  if (skin === 'a') {
    card.pack_start(topRow, false, false, 0);
    card.pack_start(artBox, false, false, 0);
    card.pack_start(lblTitle, false, false, 0);
    card.pack_start(lblArtist, false, false, 0);
    card.pack_start(scrub, false, false, 0);
    card.pack_start(timeRow, false, false, 0);
    ctlRow.pack_start(prev, false, false, 0);
    ctlRow.pack_start(btnPlay, false, false, 0);
    ctlRow.pack_start(next, false, false, 0);
    card.pack_start(ctlRow, false, false, 8);
    card.set_size_request(300, -1);
  } else if (skin === 'b') {
    let infoRow = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 12 });
    let infoCol = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL });
    infoCol.set_valign(Gtk.Align.CENTER);
    infoCol.pack_start(lblTitle, false, false, 0);
    infoCol.pack_start(lblArtist, false, false, 0);
    infoRow.pack_start(artBox, false, false, 0);
    infoRow.pack_start(infoCol, true, true, 0);
    infoRow.pack_end(skinBtn, false, false, 0);
    card.pack_start(infoRow, false, false, 0);
    card.pack_start(scrub, false, false, 6);
    card.pack_start(timeRow, false, false, 0);
    ctlRow.pack_start(prev, false, false, 0);
    ctlRow.pack_start(btnPlay, false, false, 0);
    ctlRow.pack_start(next, false, false, 0);
    ctlRow.pack_start(shuf, false, false, 0);
    ctlRow.pack_start(loop, false, false, 0);
    card.pack_start(ctlRow, false, false, 6);
    card.set_size_request(330, -1);
  } else {
    let infoRow = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, spacing: 12 });
    let infoCol = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL });
    infoCol.set_valign(Gtk.Align.CENTER);
    infoCol.pack_start(lblTitle, false, false, 0);
    infoCol.pack_start(lblArtist, false, false, 0);
    infoRow.pack_start(artBox, false, false, 0);
    infoRow.pack_start(infoCol, true, true, 0);
    infoRow.pack_end(skinBtn, false, false, 0);
    card.pack_start(infoRow, false, false, 0);
    card.pack_start(scrub, false, false, 6);
    ctlRow.pack_start(prev, false, false, 0);
    ctlRow.pack_start(btnPlay, false, false, 0);
    ctlRow.pack_start(next, false, false, 0);
    card.pack_start(ctlRow, false, false, 6);
    card.set_size_request(330, -1);
  }

  outer.add(card);
  outer.show_all();
  positionWindow();
}

function positionWindow() {
  let display = Gdk.Display.get_default();
  let monitor = display.get_primary_monitor() || display.get_monitor(0);
  let geo = monitor.get_geometry();
  let [w, h] = win.get_size();
  win.move(geo.x + Math.floor((geo.width - w) / 2), geo.y + BAR_HEIGHT + 6);
}

let lastArtSig = null;
function refresh(force) {
  let d = getData();
  if (!d.ok) {
    lblTitle.set_text('无播放中');
    lblArtist.set_text('');
    lblCur.set_text('0:00'); lblRem.set_text('0:00');
    artBox.get_style_context().add_class('art-fallback');
    imgArt.clear();
    btnPlay.set_label('⏯');
    scrub.set_sensitive(false);
    return GLib.SOURCE_CONTINUE;
  }
  scrub.set_sensitive(true);
  lblTitle.set_text(d.title);
  lblArtist.set_text(skin === 'b' && d.album ? (d.artist + ' · ' + d.album) : d.artist);
  btnPlay.set_label(d.status === 'Playing' ? '⏸' : '▶');
  if (!userSeeking) {
    scrub.set_range(0, Math.max(1, d.lengthSec));
    scrub.set_value(Math.min(d.posSec, d.lengthSec));
  }
  lblCur.set_text(fmtTime(d.posSec));
  lblRem.set_text('-' + fmtTime(Math.max(0, d.lengthSec - d.posSec)));
  let artFile = ensureArt(d.artUrl);
  let sig = (artFile || '') + '|' + skin;
  if (force || sig !== lastArtSig) {
    lastArtSig = sig;
    let size = (skin === 'a') ? 250 : (skin === 'b' ? 64 : 58);
    if (artFile) {
      try {
        let pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(artFile, size, size, true);
        imgArt.set_from_pixbuf(pb);
        artBox.get_style_context().remove_class('art-fallback');
      } catch (e) {
        imgArt.clear(); artBox.set_size_request(size, size);
        artBox.get_style_context().add_class('art-fallback');
      }
    } else {
      imgArt.clear(); artBox.set_size_request(size, size);
      artBox.get_style_context().add_class('art-fallback');
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

buildLayout();
win.show_all();
positionWindow();
refresh(true);
GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => refresh(false));
Gtk.main();

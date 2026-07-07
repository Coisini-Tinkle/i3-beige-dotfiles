#!/usr/bin/env gjs

imports.gi.versions.Gtk = '3.0';
imports.gi.versions.Gdk = '3.0';

const {Gdk, GLib, Gtk, Pango} = imports.gi;

const DEFAULTS = {
  title: '下拉动画测试',
  body: '从 polybar 下沿展开，然后自动收回',
  progress: -1,
  width: 0,
  minWidth: 200,
  maxWidth: 560,
  height: 150,
  barHeight: 34,
  barY: 0,
  overlap: 0,
  xOffset: -22,
  duration: 360,
  hold: 2200,
  notchWidth: 136,
  notchDepth: 14,
  islandWidth: 160,
  islandHeight: 34,
  islandRadius: 17,
  expandedRadius: 20,
  topInsetRadius: 22,
  bottomRadius: 18,
  slideProgress: 0,
  panelWidth: 0,
  widthDuration: 250,
  urgency: 1,
};

function parseArgs(argv) {
  const opts = Object.assign({}, DEFAULTS);
  let widthProvided = false;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const next = () => argv[++i] || '';
    switch (arg) {
      case '--title':
        opts.title = next();
        break;
      case '--body':
        opts.body = next();
        break;
      case '--progress':
        opts.progress = Math.max(0, Math.min(100, Number(next())));
        break;
      case '--width':
        opts.width = Number(next()) || opts.width;
        widthProvided = true;
        break;
      case '--x-offset':
        opts.xOffset = Number(next()) || opts.xOffset;
        break;
      case '--height':
        opts.height = Number(next()) || opts.height;
        break;
      case '--bar-height':
        opts.barHeight = Number(next()) || opts.barHeight;
        opts.islandHeight = opts.barHeight;
        opts.islandRadius = opts.islandHeight / 2;
        break;
      case '--bar-y':
        opts.barY = Number(next()) || opts.barY;
        break;
      case '--overlap':
        opts.overlap = Number(next()) || opts.overlap;
        break;
      case '--duration':
        opts.duration = Number(next()) || opts.duration;
        break;
      case '--hold':
        opts.hold = Number(next()) || opts.hold;
        break;
      case '--notch-width':
        opts.notchWidth = Number(next()) || opts.notchWidth;
        break;
      case '--notch-depth':
        opts.notchDepth = Number(next()) || opts.notchDepth;
        break;
      case '--island-width':
        opts.islandWidth = Number(next()) || opts.islandWidth;
        break;
      case '--island-height':
        opts.islandHeight = Number(next()) || opts.islandHeight;
        opts.islandRadius = opts.islandHeight / 2;
        break;
      case '--top-inset-radius':
        opts.topInsetRadius = Number(next()) || opts.topInsetRadius;
        break;
      case '--bottom-radius':
        opts.bottomRadius = Number(next()) || opts.bottomRadius;
        break;
      case '--urgency':
        opts.urgency = Math.max(0, Math.min(2, Number(next()) || 0));
        break;
      case '--min-width':
        opts.minWidth = Number(next()) || opts.minWidth;
        break;
      case '--max-width':
        opts.maxWidth = Number(next()) || opts.maxWidth;
        break;
      default:
        break;
    }
  }
  if (!widthProvided) {
    opts.panelWidth = calcPanelWidth(opts);
  } else {
    opts.panelWidth = opts.width;
  }
  opts.width = opts.islandWidth;
  return opts;
}

function calcPanelWidth(opts) {
  const screen = Gdk.Screen.get_default();
  if (!screen) return opts.islandWidth;
  const ctx = Gdk.pango_context_get_for_screen(screen);

  const padding = 24 * 2 + 48;

  ctx.set_font_description(
    Pango.FontDescription.from_string('JetBrainsMono Nerd Font Mono 11')
  );
  const titleLayout = Pango.Layout.new(ctx);
  titleLayout.set_text(opts.title, -1);
  const [tw] = titleLayout.get_pixel_size();

  ctx.set_font_description(
    Pango.FontDescription.from_string('JetBrainsMono Nerd Font Mono 10')
  );
  const bodyLayout = Pango.Layout.new(ctx);
  bodyLayout.set_text(opts.body, -1);
  const [bw] = bodyLayout.get_pixel_size();

  const textWidth = Math.max(tw, bw);
  return Math.max(opts.islandWidth, Math.min(opts.maxWidth, textWidth + padding));
}

function easeOutQuint(t) {
  return 1 - Math.pow(1 - t, 5);
}

function cssEscape(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function loadCss() {
  const css = `
    window.drop-panel {
      background-color: transparent;
      border-radius: 0;
    }

    .drop-card {
      background: transparent;
      color: #f5ebe1;
      border-radius: 0;
      border: none;
      box-shadow: none;
      padding: 0;
      font-family: "JetBrainsMono Nerd Font Mono", "Noto Sans CJK SC", monospace;
    }

    .drop-bodybox {
      background: transparent;
      border-radius: 0;
      border: none;
      padding: 0 24px 18px;
    }

    .drop-title {
      color: #f5ebe1;
      font-weight: 700;
      font-size: 11pt;
    }

    .drop-body {
      color: #dcd3ca;
      font-size: 10pt;
      margin-top: 4px;
    }

    .drop-urgency-low .drop-title { color: #dcd3ca; }
    .drop-urgency-low .drop-body { color: #9f978f; }
    .drop-urgency-critical .drop-title { color: #f29aaa; }

    .drop-accent {
      background: #ca7081;
      border-radius: 999px;
      min-height: 2px;
      margin-bottom: 10px;
    }

    progressbar trough {
      min-height: 5px;
      border-radius: 999px;
      background: #2a2a2a;
      border: none;
    }

    progressbar progress {
      min-height: 5px;
      border-radius: 999px;
      background: #ca7081;
      border: none;
    }
  `;

  const provider = new Gtk.CssProvider();
  provider.load_from_data(css);
  Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(),
    provider,
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
  );
}

function drawPanelShape(area, cr, opts) {
  const alloc = area.get_allocation();
  const w = alloc.width;
  const h = alloc.height;
  const p = Math.max(0, Math.min(1, opts.slideProgress));

  cr.newPath();
  islandShape(cr, w, h, opts, p, 4);
  cr.setSourceRGBA(0, 0, 0, 0.18 * p);
  cr.fill();

  // 黑色动态岛主体：展开态保留上凹肩部、下凸圆角。
  cr.newPath();
  islandShape(cr, w, h, opts, p, 0);
  cr.setSourceRGBA(0x1a / 255, 0x1a / 255, 0x1a / 255, 1);
  cr.fill();

  cr.newPath();
  islandShape(cr, Math.max(1, w - 1), Math.max(1, h - 1), opts, p, 0.5);
  cr.setSourceRGBA(0xf5 / 255, 0xeb / 255, 0xe1 / 255, 0.08 + 0.06 * p);
  cr.setLineWidth(1);
  cr.stroke();
  return false;
}

function islandShape(cr, w, h, opts, progress, yOffset) {
  const k = 0.5522847498;
  const p = Math.max(0, Math.min(1, progress));
  const collapsed = h <= opts.islandHeight + 6 || p < 0.12;
  if (collapsed) {
    const pillW = w;
    const pillX = 0;
    const r = Math.min(opts.islandRadius, pillW / 2, h / 2);
    roundedRect(cr, pillX, yOffset, pillW, Math.max(1, h - yOffset), r, k);
    return;
  }

  const topD = Math.min(opts.topInsetRadius, h * 0.26, w * 0.12);
  const bottomR = Math.min(opts.bottomRadius, w / 2, h / 2);
  const neckW = Math.min(w - topD * 2, opts.islandWidth + (w - opts.islandWidth) * 0.22);
  const neckLeft = (w - neckW) / 2;
  const neckRight = neckLeft + neckW;
  const y = yOffset;
  const bottom = h;

  cr.moveTo(neckLeft, y);
  cr.lineTo(neckRight, y);
  cr.curveTo(
    neckRight + (w - neckRight) * 0.48, y,
    w, y + topD * 0.34,
    w, y + topD
  );
  cr.lineTo(w, bottom - bottomR);
  cr.curveTo(w, bottom - bottomR + bottomR * k, w - bottomR + bottomR * k, bottom, w - bottomR, bottom);
  cr.lineTo(bottomR, bottom);
  cr.curveTo(bottomR - bottomR * k, bottom, 0, bottom - bottomR + bottomR * k, 0, bottom - bottomR);
  cr.lineTo(0, y + topD);
  cr.curveTo(
    0, y + topD * 0.34,
    neckLeft - neckLeft * 0.48, y,
    neckLeft, y
  );
  cr.closePath();
}

function roundedRect(cr, x, y, w, h, r, k = 0.5522847498) {
  cr.moveTo(x + r, y);
  cr.lineTo(x + w - r, y);
  cr.curveTo(x + w - r + r * k, y, x + w, y + r - r * k, x + w, y + r);
  cr.lineTo(x + w, y + h - r);
  cr.curveTo(x + w, y + h - r + r * k, x + w - r + r * k, y + h, x + w - r, y + h);
  cr.lineTo(x + r, y + h);
  cr.curveTo(x + r - r * k, y + h, x, y + h - r + r * k, x, y + h - r);
  cr.lineTo(x, y + r);
  cr.curveTo(x, y + r - r * k, x + r - r * k, y, x + r, y);
  cr.closePath();
}

function getGeometry() {
  const display = Gdk.Display.get_default();
  const seat = display.get_default_seat();
  const pointer = seat ? seat.get_pointer() : null;
  const [, x, y] = pointer ? pointer.get_position() : [null, 0, 0];
  const monitor = display.get_monitor_at_point(x, y) ||
    display.get_primary_monitor() ||
    display.get_monitor(0);
  return monitor.get_geometry();
}

function positionWindow(win, overlay, shape, bodyBox, opts, width, height, y) {
  const geom = getGeometry();
  const roundedWidth = Math.max(1, Math.round(width));
  const roundedHeight = Math.max(1, Math.round(height));
  const x = Math.round(geom.x + (geom.width - width) / 2 + opts.xOffset);
  win.set_size_request(roundedWidth, roundedHeight);
  overlay.set_size_request(roundedWidth, roundedHeight);
  shape.set_size_request(roundedWidth, roundedHeight);
  bodyBox.set_size_request(roundedWidth, roundedHeight);
  win.move(x, Math.round(geom.y + y));
  win.resize(roundedWidth, roundedHeight);
}

function animateIsland(win, overlay, shape, bodyBox, opts, from, to, duration, done) {
  const start = GLib.get_monotonic_time() / 1000;
  const frameMs = 1000 / 60;

  const tick = () => {
    const now = GLib.get_monotonic_time() / 1000;
    const t = Math.min(1, (now - start) / duration);
    const eased = easeOutQuint(t);
    const p = from + (to - from) * eased;
    opts.slideProgress = Math.max(0, Math.min(1, p));
    const width = opts.width;
    const height = opts.islandHeight + (opts.height - opts.islandHeight) * opts.slideProgress;
    const y = opts.barY;
    positionWindow(win, overlay, shape, bodyBox, opts, width, height, y);
    shape.queue_draw();
    bodyBox.set_opacity(Math.max(0, Math.min(1, (opts.slideProgress - 0.2) / 0.45)));

    if (t >= 1) {
      if (done) done();
      return GLib.SOURCE_REMOVE;
    }
    return GLib.SOURCE_CONTINUE;
  };

  GLib.timeout_add(GLib.PRIORITY_DEFAULT, frameMs, tick);
}

function animateWidth(win, overlay, shape, bodyBox, opts, fromW, toW, duration, done) {
  const start = GLib.get_monotonic_time() / 1000;
  const frameMs = 1000 / 60;

  const tick = () => {
    const now = GLib.get_monotonic_time() / 1000;
    const t = Math.min(1, (now - start) / duration);
    const eased = easeOutQuint(t);
    const currentW = fromW + (toW - fromW) * eased;
    opts.width = Math.max(1, Math.round(currentW));
    positionWindow(win, overlay, shape, bodyBox, opts, opts.width, opts.islandHeight, opts.barY);
    shape.queue_draw();

    if (t >= 1) {
      if (done) done();
      return GLib.SOURCE_REMOVE;
    }
    return GLib.SOURCE_CONTINUE;
  };

  GLib.timeout_add(GLib.PRIORITY_DEFAULT, frameMs, tick);
}

function buildWindow(opts) {
  const win = new Gtk.Window({
    type: Gtk.WindowType.POPUP,
    decorated: false,
    resizable: false,
    skip_taskbar_hint: true,
    skip_pager_hint: true,
    app_paintable: true,
    name: 'drop-panel',
  });
  win.set_type_hint(Gdk.WindowTypeHint.NOTIFICATION);
  win.set_wmclass('notification-drop-panel', 'notification-drop-panel');
  win.set_accept_focus(false);
  win.set_keep_above(true);
  win.set_default_size(opts.width, opts.islandHeight);
  win.set_size_request(1, 1);
  win.get_style_context().add_class('drop-panel');

  const overlay = new Gtk.Overlay();
  overlay.set_size_request(1, 1);
  overlay.get_style_context().add_class('drop-card');

  const shape = new Gtk.DrawingArea({hexpand: true, vexpand: true});
  shape.set_size_request(1, 1);
  shape.connect('draw', (_area, cr) => drawPanelShape(_area, cr, opts));
  overlay.add(shape);

  const bodyBox = new Gtk.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 0,
    hexpand: true,
    vexpand: true,
    margin_top: opts.islandHeight + 8,
  });
  bodyBox.set_opacity(0);
  bodyBox.get_style_context().add_class('drop-bodybox');
  if (opts.urgency === 0) bodyBox.get_style_context().add_class('drop-urgency-low');
  if (opts.urgency === 2) bodyBox.get_style_context().add_class('drop-urgency-critical');
  overlay.add_overlay(bodyBox);

  const title = new Gtk.Label({
    label: cssEscape(opts.title),
    xalign: 0,
    ellipsize: 3,
    use_markup: true,
  });
  title.get_style_context().add_class('drop-title');
  bodyBox.pack_start(title, false, false, 0);

  const body = new Gtk.Label({
    label: cssEscape(opts.body),
    xalign: 0,
    wrap: true,
    max_width_chars: 44,
    lines: 2,
    ellipsize: 3,
    use_markup: true,
  });
  body.get_style_context().add_class('drop-body');
  bodyBox.pack_start(body, false, false, 0);

  win.add(overlay);
  return [win, overlay, shape, bodyBox];
}

function main(argv) {
  Gtk.init(null);
  loadCss();

  const opts = parseArgs(argv);
  const [win, overlay, shape, bodyBox] = buildWindow(opts);

  win.connect('destroy', () => Gtk.main_quit());

  // Phase 1: show 200x34 pill covering clock module
  opts.slideProgress = 0;
  positionWindow(win, overlay, shape, bodyBox, opts, opts.islandWidth, opts.islandHeight, opts.barY);
  win.show_all();

  // Phase 3: horizontal expansion
  const expandHorizontal = () => {
    if (opts.panelWidth <= opts.islandWidth) {
      expandVertical();
      return;
    }
    animateWidth(win, overlay, shape, bodyBox, opts,
      opts.islandWidth, opts.panelWidth, opts.widthDuration, expandVertical);
  };

  // Phase 4: vertical expansion
  const expandVertical = () => {
    animateIsland(win, overlay, shape, bodyBox, opts, 0, 1, opts.duration, () => {
      // Phase 5: hold
      GLib.timeout_add(GLib.PRIORITY_DEFAULT, opts.hold, () => {
        collapseVertical();
        return GLib.SOURCE_REMOVE;
      });
    });
  };

  // Phase 6a: collapse vertical
  const collapseVertical = () => {
    animateIsland(win, overlay, shape, bodyBox, opts, 1, 0, opts.duration, collapseHorizontal);
  };

  // Phase 6b: collapse horizontal
  const collapseHorizontal = () => {
    if (opts.panelWidth <= opts.islandWidth) {
      win.destroy();
      return;
    }
    animateWidth(win, overlay, shape, bodyBox, opts,
      opts.panelWidth, opts.islandWidth, opts.widthDuration, () => win.destroy());
  };

  expandHorizontal();

  Gtk.main();
}

main(ARGV);

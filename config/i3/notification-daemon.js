#!/usr/bin/env gjs

const {GLib, Gio} = imports.gi;

const PANEL_PATH = GLib.build_filenamev([GLib.get_home_dir(), '.config', 'i3', 'notification-drop-panel.js']);
const DBUS_NAME = 'org.freedesktop.Notifications';
const DBUS_PATH = '/org/freedesktop/Notifications';
const MAX_QUEUE = 3;
const DEFAULT_HOLD = [1800, 3000, 8000];
const MIN_HOLD = 800;
const MAX_HOLD = 15000;

const IFACE_XML = `
<node>
  <interface name="org.freedesktop.Notifications">
    <method name="Notify">
      <arg type="s" direction="in" name="app_name"/>
      <arg type="u" direction="in" name="replaces_id"/>
      <arg type="s" direction="in" name="app_icon"/>
      <arg type="s" direction="in" name="summary"/>
      <arg type="s" direction="in" name="body"/>
      <arg type="as" direction="in" name="actions"/>
      <arg type="a{sv}" direction="in" name="hints"/>
      <arg type="i" direction="in" name="expire_timeout"/>
      <arg type="u" direction="out" name="id"/>
    </method>
    <method name="CloseNotification">
      <arg type="u" direction="in" name="id"/>
    </method>
    <method name="GetCapabilities">
      <arg type="as" direction="out" name="capabilities"/>
    </method>
    <method name="GetServerInformation">
      <arg type="s" direction="out" name="name"/>
      <arg type="s" direction="out" name="vendor"/>
      <arg type="s" direction="out" name="version"/>
      <arg type="s" direction="out" name="spec_version"/>
    </method>
    <signal name="NotificationClosed">
      <arg type="u" name="id"/>
      <arg type="u" name="reason"/>
    </signal>
    <signal name="ActionInvoked">
      <arg type="u" name="id"/>
      <arg type="s" name="action_key"/>
    </signal>
  </interface>
</node>`;

let nextId = 1;
let currentProcess = null;
let currentNotification = null;
let currentCloseReason = 1;
let currentSuppressClose = false;
let queue = [];
let bus = null;
let loop = null;

function unpack(value) {
  return value && typeof value.deep_unpack === 'function' ? value.deep_unpack() : value;
}

function getUrgency(hints) {
  if (!hints || !Object.prototype.hasOwnProperty.call(hints, 'urgency')) return 1;
  const urgency = Number(unpack(hints.urgency));
  return Math.max(0, Math.min(2, Number.isFinite(urgency) ? urgency : 1));
}

function getHold(notification) {
  if (notification.expireTimeout > 0) {
    return Math.max(MIN_HOLD, Math.min(MAX_HOLD, notification.expireTimeout));
  }
  return DEFAULT_HOLD[notification.urgency];
}

function makeNotification(id, appName, title, body, expireTimeout, urgency) {
  return {
    id,
    appName: appName || '',
    title: title || '',
    body: body || '',
    expireTimeout,
    urgency,
  };
}

function showNext() {
  if (currentProcess || queue.length === 0) return;
  showNotification(queue.shift());
}

function showNotification(notification) {
  if (currentProcess) return;

  currentNotification = notification;
  currentCloseReason = 1;
  currentSuppressClose = false;
  const hold = getHold(notification);
  const args = [
    'gjs', PANEL_PATH,
    '--title', notification.title,
    '--body', notification.body,
    '--hold', String(hold),
    '--urgency', String(notification.urgency),
  ];

  log(`Launching notification ${notification.id} (${notification.appName || 'unknown'}, urgency=${notification.urgency}, hold=${hold})`);
  try {
    currentProcess = Gio.Subprocess.new(args, Gio.SubprocessFlags.NONE);
    log('Panel launched, PID: ' + currentProcess.get_identifier());
  } catch (e) {
    log('Failed to launch panel: ' + e.message);
    currentNotification = null;
    emitClosed(notification.id, 4);
    showNext();
    return;
  }

  currentProcess.wait_async(null, (proc, res) => {
    try {
      proc.wait_finish(res);
    } catch (e) {}

    const finished = currentNotification;
    const closeReason = currentCloseReason;
    const suppressClose = currentSuppressClose;
    currentProcess = null;
    currentNotification = null;
    currentCloseReason = 1;
    currentSuppressClose = false;

    if (finished && !suppressClose) {
      emitClosed(finished.id, closeReason);
    }
    showNext();
  });
}

function enqueue(notification) {
  if (notification.appName) {
    const sameApp = queue.findIndex(item => item.appName === notification.appName);
    if (sameApp >= 0) {
      const replaced = queue[sameApp];
      queue[sameApp] = notification;
      emitClosed(replaced.id, 4);
      log(`Merged queued notification ${replaced.id} into ${notification.id} for ${notification.appName}`);
      return;
    }
  }

  if (queue.length >= MAX_QUEUE) {
    const dropped = queue.shift();
    emitClosed(dropped.id, 4);
    log(`Dropped queued notification ${dropped.id}; queue limit is ${MAX_QUEUE}`);
  }
  queue.push(notification);
  log(`Queued notification ${notification.id}; pending=${queue.length}`);
}

function replaceNotification(notification) {
  const queuedIndex = queue.findIndex(item => item.id === notification.id);
  if (queuedIndex >= 0) {
    queue[queuedIndex] = notification;
    log(`Replaced queued notification ${notification.id}`);
    return true;
  }

  if (currentNotification && currentNotification.id === notification.id && currentProcess) {
    queue = queue.filter(item => item.id !== notification.id);
    queue.unshift(notification);
    currentSuppressClose = true;
    currentProcess.force_exit();
    log(`Replacing active notification ${notification.id}`);
    return true;
  }
  return false;
}

function emitClosed(id, reason) {
  if (!bus || !id) return;
  try {
    bus.emit_signal(
      null,
      DBUS_PATH,
      DBUS_NAME,
      'NotificationClosed',
      new GLib.Variant('(uu)', [id, reason])
    );
  } catch (e) {}
}

const nodeInfo = Gio.DBusNodeInfo.new_for_xml(IFACE_XML);

function handleMethodCall(connection, sender, path, iface, method, paramsV, invocation) {
  const params = paramsV.deep_unpack();
  log('Method called: ' + method);

  switch (method) {
    case 'Notify': {
      const [appName, replacesId, , summary, body, , hints, expireTimeout] = params;
      const replacementExists = replacesId > 0 && (
        (currentNotification && currentNotification.id === replacesId) ||
        queue.some(item => item.id === replacesId)
      );
      const id = replacementExists ? replacesId : nextId++;
      const notification = makeNotification(
        id, appName, summary, body, expireTimeout, getUrgency(hints)
      );

      if (replacementExists && replaceNotification(notification)) {
        // Replacement keeps the original notification ID and queue position.
      } else if (currentProcess) {
        enqueue(notification);
      } else {
        showNotification(notification);
      }
      invocation.return_value(new GLib.Variant('(u)', [id]));
      break;
    }
    case 'CloseNotification': {
      const [id] = params;
      const queuedIndex = queue.findIndex(item => item.id === id);
      if (queuedIndex >= 0) {
        queue.splice(queuedIndex, 1);
        emitClosed(id, 3);
      }
      if (currentNotification && id === currentNotification.id && currentProcess) {
        currentCloseReason = 3;
        currentSuppressClose = false;
        currentProcess.force_exit();
      }
      invocation.return_value(null);
      break;
    }
    case 'GetCapabilities':
      invocation.return_value(new GLib.Variant('(as)', [['body']]));
      break;
    case 'GetServerInformation':
      invocation.return_value(new GLib.Variant('(ssss)', [
        'dynamic-island', 'custom', '1.1', '1.2'
      ]));
      break;
    default:
      invocation.return_error_literal(Gio.DBusError, Gio.DBusError.UNKNOWN_METHOD,
        'Unknown method: ' + method);
  }
}

function main() {
  bus = Gio.bus_get_sync(Gio.BusType.SESSION, null);

  bus.register_object(
    DBUS_PATH,
    nodeInfo.interfaces[0],
    handleMethodCall,
    null,
    null
  );

  loop = GLib.MainLoop.new(null, false);

  Gio.bus_own_name_on_connection(
    bus,
    DBUS_NAME,
    Gio.BusNameOwnerFlags.REPLACE | Gio.BusNameOwnerFlags.DO_NOT_QUEUE,
    () => log('Bus name acquired'),
    (connection, name) => {
      log('Unable to own bus name; exiting duplicate daemon: ' + name);
      loop.quit();
    }
  );

  log('Dynamic Island notification daemon started');
  loop.run();
}

main();

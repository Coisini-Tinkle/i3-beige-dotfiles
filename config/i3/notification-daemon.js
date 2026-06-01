#!/usr/bin/env gjs

const {GLib, Gio} = imports.gi;

const PANEL_PATH = GLib.build_filenamev([
  GLib.get_home_dir(),
  '.config',
  'i3',
  'notification-drop-panel.js',
]);
const DBUS_NAME = 'org.freedesktop.Notifications';
const DBUS_PATH = '/org/freedesktop/Notifications';

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
let currentId = 0;
let queued = null;
let bus = null;

function showNotification(id, title, body, expireTimeout) {
  if (currentProcess) {
    currentProcess.force_exit();
    currentProcess = null;
  }

  currentId = id;
  const hold = expireTimeout > 0 ? expireTimeout : 3000;
  const args = ['gjs', PANEL_PATH, '--title', title, '--body', body, '--hold', String(hold)];

  log('Launching panel: ' + args.join(' '));
  try {
    currentProcess = Gio.Subprocess.new(args, Gio.SubprocessFlags.NONE);
    log('Panel launched, PID: ' + currentProcess.get_identifier());
  } catch (e) {
    log('Failed to launch panel: ' + e.message);
    return;
  }

  currentProcess.wait_async(null, (proc, res) => {
    try {
      proc.wait_finish(res);
    } catch (e) {}
    currentProcess = null;
    emitClosed(currentId, 1);

    if (queued) {
      const q = queued;
      queued = null;
      showNotification(q.id, q.title, q.body, q.expireTimeout);
    }
  });
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
      const [, , , summary, body, , , expireTimeout] = params;
      const id = nextId++;
      if (currentProcess) {
        queued = {id, title: summary, body: body || '', expireTimeout};
        if (currentProcess) {
          currentProcess.force_exit();
        }
      } else {
        showNotification(id, summary, body || '', expireTimeout);
      }
      invocation.return_value(new GLib.Variant('(u)', [id]));
      break;
    }
    case 'CloseNotification': {
      const [id] = params;
      if (id === currentId && currentProcess) {
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
        'dynamic-island', 'custom', '1.0', '1.2'
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

  const loop = GLib.MainLoop.new(null, false);

  const ownerId = Gio.bus_own_name_on_connection(
    bus,
    DBUS_NAME,
    Gio.BusNameOwnerFlags.REPLACE,
    () => log('Bus name acquired'),
    (connection, name) => {
      log('Lost bus name, retrying in 1s: ' + name);
      GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
        Gio.bus_own_name_on_connection(
          bus,
          DBUS_NAME,
          Gio.BusNameOwnerFlags.REPLACE,
          () => log('Bus name re-acquired'),
          (conn2, name2) => {
            log('Lost bus name again: ' + name2);
          }
        );
        return GLib.SOURCE_REMOVE;
      });
    }
  );

  log('Dynamic Island notification daemon started');
  loop.run();
}

main();

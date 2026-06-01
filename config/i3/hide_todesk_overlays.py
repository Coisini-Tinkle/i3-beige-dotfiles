#!/usr/bin/env python3

import time

from Xlib import X, display


TOP_EDGE_LIMIT = 40
MAX_WIDTH = 220
MAX_HEIGHT = 220
RETRIES = 8
SLEEP = 0.5


def get_text_prop(dpy, win, atom_name):
    atom = dpy.intern_atom(atom_name)
    prop = win.get_full_property(atom, X.AnyPropertyType)
    if not prop or not prop.value:
        return ""
    value = prop.value
    if isinstance(value, bytes):
        return value.decode("utf-8", "ignore")
    if isinstance(value, str):
        return value
    try:
        return bytes(value).decode("utf-8", "ignore")
    except Exception:
        try:
            return b"".join(value).decode("utf-8", "ignore")
        except Exception:
            return ""


def get_atom_names(dpy, win, atom_name):
    atom = dpy.intern_atom(atom_name)
    prop = win.get_full_property(atom, X.AnyPropertyType)
    if not prop or not prop.value:
        return []
    names = []
    for value in prop.value:
        try:
            names.append(dpy.get_atom_name(value))
        except Exception:
            pass
    return names


def is_todesk_overlay(dpy, root, win):
    wm_class = get_text_prop(dpy, win, "WM_CLASS")
    wm_name = get_text_prop(dpy, win, "_NET_WM_NAME") or get_text_prop(dpy, win, "WM_NAME")
    if "ToDesk" not in wm_class and "ToDesk" not in wm_name:
        return False

    geom = win.get_geometry()
    translated = win.translate_coords(root, 0, 0)
    y = translated.y
    width = geom.width
    height = geom.height

    window_types = get_atom_names(dpy, win, "_NET_WM_WINDOW_TYPE")
    is_popup = "_NET_WM_WINDOW_TYPE_POPUP_MENU" in window_types
    has_xembed = bool(get_text_prop(dpy, win, "_XEMBED_INFO"))
    small_top_window = y <= TOP_EDGE_LIMIT and width <= MAX_WIDTH and height <= MAX_HEIGHT

    return is_popup or has_xembed or small_top_window


def hide_todesk_overlays():
    dpy = display.Display()
    root = dpy.screen().root
    changed = False

    for child in root.query_tree().children:
        try:
            if is_todesk_overlay(dpy, root, child):
                child.configure(x=-10000, y=-10000)
                changed = True
        except Exception:
            continue

    if changed:
        dpy.sync()


def main():
    for _ in range(RETRIES):
        hide_todesk_overlays()
        time.sleep(SLEEP)


if __name__ == "__main__":
    main()

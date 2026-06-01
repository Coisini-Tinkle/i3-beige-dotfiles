#!/usr/bin/env bash
set -u

"$HOME/.config/kitty/random-bg.sh"

exec env \
    GLFW_IM_MODULE=ibus \
    GTK_IM_MODULE=fcitx \
    QT_IM_MODULE=fcitx \
    XMODIFIERS=@im=fcitx \
    kitty "$@"

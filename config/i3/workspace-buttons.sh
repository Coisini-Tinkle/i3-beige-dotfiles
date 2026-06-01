#!/usr/bin/env bash

set -euo pipefail

readonly WORKSPACES_JSON='[
  {"num":1,"full":"1:I"},
  {"num":2,"full":"2:II"},
  {"num":3,"full":"3:III"},
  {"num":4,"full":"4:IV"},
  {"num":5,"full":"5:V"},
  {"num":6,"full":"6:VI"},
  {"num":7,"full":"7:VII"},
  {"num":8,"full":"8:VIII"},
  {"num":9,"full":"9:IX"},
  {"num":10,"full":"10:X"}
]'

render_buttons() {
  local workspaces outputs tree
  workspaces="$(i3-msg -t get_workspaces)"
  outputs="$(i3-msg -t get_outputs)"
  tree="$(i3-msg -t get_tree)"

  jq -cn \
    --argjson specs "${WORKSPACES_JSON}" \
    --argjson workspaces "${workspaces}" \
    --argjson outputs "${outputs}" \
    --argjson tree "${tree}" '
    def active_outputs:
      $outputs | map(select(.active == true));

    def internal_output:
      (active_outputs | map(select(.name | test("^eDP"))) | first // empty | .name) // null;

    def external_output($internal):
      (active_outputs | map(select(.name != $internal)) | first // empty | .name) // null;

    def target_output:
      (active_outputs | map(select(.focused == true)) | first // empty)
      // (active_outputs | map(select(.primary == true)) | first // empty)
      // (active_outputs | first // empty)
      | .name // "primary";

    def desired_output($num; $external; $internal; $fallback):
      if ($external != null and $internal != null) then
        if $num <= 5 then $external else $internal end
      else
        $fallback
      end;

    def window_nodes_for_workspace($num):
      [
        $tree
        | recurse((.nodes + .floating_nodes)[]?)
        | select(.type == "workspace" and .num == $num)
        | recurse((.nodes + .floating_nodes)[]?)
        | select(
            .type != "workspace"
            and (
              .app_id != null
              or (.window_properties.class // null) != null
              or (.name // "") != ""
            )
          )
      ]
      | unique_by(.id);

    def focused_or_first_window($num):
      window_nodes_for_workspace($num) as $nodes
      | ($nodes | map(select(.focused == true)) | first)
      // ($nodes | first);

    def shorten_fallback($value):
      $value
      | gsub("^org\\."; "")
      | gsub("\\.desktop$"; "")
      | gsub("[._[:space:]]+"; "-")
      | split("-")[0]
      | ascii_downcase
      | if length > 10 then .[0:10] else . end;

    def app_short_name($node):
      (($node.app_id // $node.window_properties.class // $node.name // "") | ascii_downcase) as $app
      | if $app == "" then
          null
        elif ($app | test("firefox|chrome|chromium|brave|qutebrowser|browser|zen")) then
          "web"
        elif ($app | test("cursor|vscode|code-oss|codium|code|zed|jetbrains|idea|pycharm|webstorm|clion|goland")) then
          "code"
        elif ($app | test("kitty|wezterm|alacritty|terminal|xterm|konsole|gnome-terminal|xfce4-terminal")) then
          "term"
        elif ($app | test("telegram|discord|slack|wechat|feishu|qq|signal|element")) then
          "chat"
        elif ($app | test("nautilus|dolphin|nemo|thunar|pcmanfm")) then
          "files"
        elif ($app | test("mpv|vlc|spotify|obs|kodi|plex")) then
          "media"
        elif ($app | test("evince|okular|zathura|sioyek|wps|libreoffice")) then
          "doc"
        elif ($app | test("pavucontrol|blueman|nm-connection-editor|settings")) then
          "sys"
        else
          shorten_fallback($node.app_id // $node.window_properties.class // $node.name // "app")
        end;

    def workspace_label($spec):
      focused_or_first_window($spec.num) as $node
      | if $node == null then
          "\($spec.num)"
        else
          "(\($spec.num)) \(app_short_name($node))"
        end;

    def extra_workspaces:
      $workspaces
      | map(select(.num as $num | ([ $specs[].num ] | index($num) | not)))
      | sort_by(.output, .num, .name);

    internal_output as $internal
    | external_output($internal) as $external
    | target_output as $fallback
    | (
        [
          $specs[] as $spec
          | ($workspaces | map(select(.num == $spec.num)) | first) as $current
          | focused_or_first_window($spec.num) as $node
          | if $current then
              if $node == null then
                $current + {
                  id: $current.id,
                  num: $spec.num,
                  name: workspace_label($spec)
                }
              else
                ($current | del(.num)) + {
                  id: $current.id,
                  name: workspace_label($spec)
                }
              end
            else
              {
                num: $spec.num,
                name: $spec.full,
                output: desired_output($spec.num; $external; $internal; $fallback),
                visible: false,
                focused: false,
                urgent: false
              }
            end
        ]
        + (extra_workspaces | map(. + { id: .id }))
      )
    | sort_by(.output, .num, .name)
    | map(del(.rect))
    ' | tr -d "\n"

  printf '\n'
}

main() {
  render_buttons
  i3-msg -t subscribe -m '["workspace", "output", "window"]' | while IFS= read -r _event; do
    render_buttons
  done
}

main "$@"

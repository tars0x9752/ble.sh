#!/bin/bash

ble/is-function ble/util/idle.push && ble-import -d "$_ble_base/lib/core-complete.sh"

#------------------------------------------------------------------------------
# 公開関数と公開関数

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
                  ble/widget/complete \
                  ble/widget/menu-complete \
                  ble/widget/auto-complete-enter \
                  ble/widget/sabbrev-expand \
                  ble/widget/dabbrev-expand

function ble-sabbrev {
  # check arguments for printing
  local arg print=
  for arg; do
    if [[ $arg != -* && $arg != *=* ]]; then
      print=1
      break
    fi
  done
  if (($#==0)) || [[ $print ]]; then
    ble-import lib/core-complete && ble-sabbrev "$@"
    return $?
  fi

  local ret; ble/string#quote-command "$FUNCNAME" "$@"
  blehook/eval-after-load complete "$ret"
}

if ! declare -p _ble_complete_sabbrev &>/dev/null; then # reload #D0875
  builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_complete_sabbrev}"
fi

#------------------------------------------------------------------------------
# 設定変数

bleopt/declare -n complete_polling_cycle 50
bleopt/declare -o complete_stdin_frequency complete_polling_cycle

bleopt/declare -v complete_limit ''
bleopt/declare -v complete_limit_auto 2000
bleopt/declare -v complete_limit_auto_menu 100
bleopt/declare -v complete_timeout_auto 5000
bleopt/declare -v complete_timeout_compvar 200

bleopt/declare -v complete_ambiguous 1
bleopt/declare -v complete_contract_function_names 1
bleopt/declare -v complete_auto_complete 1
bleopt/declare -v complete_auto_history 1
bleopt/declare -n complete_auto_delay 1
bleopt/declare -v complete_auto_wordbreaks "$_ble_term_IFS"
bleopt/declare -v complete_auto_menu ''
bleopt/declare -v complete_allow_reduction ''

## @bleopt complete_menu_style
##   補完候補のリスト表示のスタイルを指定します。
##
##   dense, dense-nowrap, align, align-nowrap
##   desc, desc-text
##
bleopt/declare -n complete_menu_style align-nowrap
function bleopt/check:complete_menu_style {
  [[ $value == desc-raw ]] && value=desc
  if ! ble/is-function "ble/complete/menu-style:$value/construct-page"; then
    ble/util/print-lines \
      "bleopt: Invalid value complete_menu_style='$value'." \
      "  A function 'ble/complete/menu-style:$value/construct-page' is not defined." >&2
    return 1
  fi
  return 0
}

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
                  ble/complete/menu-style:{align,dense}{,-nowrap}/construct-page \
                  ble/complete/menu-style:linewise/construct-page \
                  ble/complete/menu-style:desc{,-raw}/construct-page

bleopt/declare -v menu_linewise_prefix ''
bleopt/declare -v menu_desc_multicolumn_width 65
bleopt/declare -v complete_menu_complete 1
bleopt/declare -v complete_menu_filter 1
bleopt/declare -v complete_menu_maxlines '-1'

bleopt/declare -v complete_skip_matched     on
bleopt/declare -v complete_menu_color       on
bleopt/declare -v complete_menu_color_match on
function ble/complete/.init-bind-readline-variables {
  local _ble_local_rlvars; ble/util/rlvar#load
  ble/util/rlvar#bind-bleopt skip-completed-text       complete_skip_matched     bool
  ble/util/rlvar#bind-bleopt colored-stats             complete_menu_color       bool
  ble/util/rlvar#bind-bleopt colored-completion-prefix complete_menu_color_match bool
  builtin unset -f "$FUNCNAME"
}
ble/complete/.init-bind-readline-variables

bleopt/declare -n menu_align_min 4
bleopt/declare -n menu_align_max 20
bleopt/declare -o complete_menu_align menu_align_max

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
                  ble/complete/menu#start \
                  ble-decode/keymap:menu/define \
                  ble-decode/keymap:auto_complete/define \
                  ble-decode/keymap:menu_complete/define \
                  ble-decode/keymap:dabbrev/define \
                  ble/complete/sabbrev/expand

#------------------------------------------------------------------------------
# 描画設定

ble/color/defface auto_complete bg=254,fg=238
ble/color/defface cmdinfo_cd_cdpath fg=26,bg=155

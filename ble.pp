#!/bin/bash
#%$> ble.sh
#%m inc (
#%%[guard="@_included".replace("[^_a-zA-Z0-9]","_")]
#%%if @_included!=1 (
#%% [@_included=1]
###############################################################################
# Included from ble-@.sh

#%% include ble-@.sh
#%%)
#%)
# bash script to be sourced from interactive shell

[ -n "$_ble_bash" ] || declare -ir _ble_bash='BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]'

function _ble_base.initialize {
  local src="$1"
  local defaultDir="$2"

  # resolve symlink
  if test -h "$src" && type -t readlink &>/dev/null; then
    src="$(readlink -f "$src")"
  fi

  local dir="${src%/*}"
  if test "$dir" != "$src"; then
    if test -z "$dir"; then
      _ble_base=/
    else
      _ble_base="$dir"
    fi
  else
    _ble_base="${defaultDir:-$PWD}"
  fi
}
_ble_base.initialize "${BASH_SOURCE[0]}"
if test ! -d "$_ble_base/ble.d"; then
  echo "ble.sh: ble.d not found!" 1>&2
  return 1
  #mkdir -p "$_ble_base/ble.d"
fi

# tmpdir
if test ! -d "$_ble_base/ble.d/tmp"; then
  mkdir -p "$_ble_base/ble.d/tmp"
  chmod a+rwxt "$_ble_base/ble.d/tmp"
fi


#%x inc.r/@/getopt/
#%x inc.r/@/core/
#%x inc.r/@/decode/
#%x inc.r/@/edit/
#%x inc.r/@/color/

#------------------------------------------------------------------------------

ble-decode-bind.cmap
ble-decode-bind
.ble-edit.default-key-bindings
.ble-edit-draw.redraw

###############################################################################

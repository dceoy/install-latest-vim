#!/usr/bin/env bash
#
# Usage:
#  ./update_vim_plugins.sh

set -euo pipefail

VIM_PLUG_VIM="${HOME}/.vim/autoload/plug.vim"
VIMRC="${HOME}/.vimrc"

if [[ ${#} -gt 0 ]] && [[ ${1} == '--debug' ]]; then
  set -x && shift
fi

if [[ ! -f "${VIM_PLUG_VIM}" ]]; then
  curl -fSL --create-dirs -o "${VIM_PLUG_VIM}" \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

vim -N -u "${VIMRC}" -U NONE -i NONE -V1 -e -s -c 'PlugUpdate --sync | qa'

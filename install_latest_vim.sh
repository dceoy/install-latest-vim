#!/usr/bin/env bash
#
# Build and install the latest version of Vim
#
# Usage:
#   install_latest_vim.sh [--debug] [-f|--force] [--lua] [--dein]
#     [--vimrc=<path>] [<dir>]
#   install_latest_vim.sh --version
#   install_latest_vim.sh -h|--help
#
# Options:
#   --debug         Run wdebug mode
#   -f, --force     Option without an argument
#   --lua           Install Lua
#   --dein          Install dein.vim
#   --vimrc=<path>  Specify a path to vimrc [default: ~/.vimrc]
#   --version       Print version
#   -h, --help      Print usage
#
# Arguments:
#   <dir>           Directory path where Vim is installed [default: ~/.vim]

set -euo pipefail

if [[ ${#} -ge 1 ]]; then
  for a in "${@}"; do
    [[ "${a}" = '--debug' ]] && set -x && break
  done
fi

COMMAND_PATH=$(realpath "${0}")
COMMAND_NAME=$(basename "${COMMAND_PATH}")
COMMAND_VERSION='v0.1.0'

FORCE=0
INSTALL_LUA=0
INSTALL_DEIN=0
DEFAULT_VIM_DIR="${HOME}/.vim"
VIMRC="${HOME}/.vimrc"
MAIN_ARGS=()

function print_version {
  echo "${COMMAND_NAME}: ${COMMAND_VERSION}"
}

function print_usage {
  sed -ne '1,2d; /^#/!q; s/^#$/# /; s/^# //p;' "${COMMAND_PATH}"
}

function abort {
  {
    if [[ ${#} -eq 0 ]]; then
      cat -
    else
      COMMAND_NAME=$(basename "${COMMAND_PATH}")
      echo "${COMMAND_NAME}: ${*}"
    fi
  } >&2
  exit 1
}

while [[ ${#} -ge 1 ]]; do
  case "${1}" in
    '--debug' )
      shift 1
      ;;
    '-f' | '--force' )
      FORCE=1 && shift 1
      ;;
    '--lua' )
      INSTALL_LUA=1 && shift 1
      ;;
    '--dein' )
      INSTALL_DEIN=1 && shift 1
      ;;
    '--vimrc' )
      VIMRC="${2}" && shift 2
      ;;
    --vimrc=* )
      VIMRC="${1#*\=}" && shift 1
      ;;
    '--version' )
      print_version && exit 0
      ;;
    '-h' | '--help' )
      print_usage && exit 0
      ;;
    -* )
      abort "invalid option: ${1}"
      ;;
    * )
      MAIN_ARGS+=("${1}") && shift 1
      ;;
  esac
done

if [[ ${#MAIN_ARGS[@]} -gt 0 ]]; then
  VIM_DIR="${MAIN_ARGS[0]}"
else
  VIM_DIR="${DEFAULT_VIM_DIR}"
fi
PATH="${VIM_DIR}/bin:${PATH}"
VIM_VER_TXT="${VIM_DIR}/VERSION.txt"
VIM_SRC_DIR="${VIM_DIR}/src"
VIM_SRC_VIM_DIR="${VIM_SRC_DIR}/vim"
VIM_SRC_ILV_DIR="${VIM_SRC_DIR}/install-latest-vim"

[[ -d "${VIM_SRC_DIR}" ]] || mkdir -p "${VIM_SRC_DIR}"

# install-latest-vim
if [[ -d "${VIM_SRC_ILV_DIR}/.git" ]]; then
  cd "${VIM_SRC_ILV_DIR}"
  if [[ ${FORCE} -eq 0 ]]; then
    git pull --prune
  else
    git fetch --prune && git reset --hard origin/master
  fi
else
  git clone https://github.com/dceoy/install-latest-vim.git "${VIM_SRC_ILV_DIR}"
fi

# Lua
if [[ ${INSTALL_LUA} -eq 0 ]]; then
  case "${OSTYPE}" in
    darwin*)
      ADD_VIM_CONFIGURE_ARGS=('--with-lua-prefix=/usr/local')
      ;;
    linux*)
      ADD_VIM_CONFIGURE_ARGS=()
      ;;
  esac
else
  ADD_VIM_CONFIGURE_ARGS=("--with-lua-prefix=${VIM_DIR}")
  LUA_FTP_URL='https://www.lua.org/ftp'
  LUA_TAR_GZ=$(curl -sSL "${LUA_FTP_URL}" | grep -oe 'lua-[0-9]\+\.[0-9]\+\.[0-9]\+\.tar\.gz' | head -1)
  VIM_SRC_LUA_DIR="${VIM_SRC_DIR}/${LUA_TAR_GZ%.tar.gz}"
  if [[ ! -d "${VIM_SRC_LUA_DIR}" ]]; then
    cd "${VIM_SRC_DIR}"
    curl -sSLO "${LUA_FTP_URL}/${LUA_TAR_GZ}"
    tar xvf "${LUA_TAR_GZ}" && rm -f "${LUA_TAR_GZ}"
    cd "${VIM_SRC_LUA_DIR}"
    if make all test; then
      make install INSTALL_TOP="${VIM_DIR}"
    else
      rm -rf "${VIM_SRC_LUA_DIR}" && exit 1
    fi
  fi
fi

# Vim
if [[ -d "${VIM_SRC_VIM_DIR}/.git" ]]; then
  cd "${VIM_SRC_VIM_DIR}"
  VIM_CURRENT_VER="$(git describe --tags)"
  git fetch --prune
else
  VIM_CURRENT_VER=''
  git clone https://github.com/vim/vim.git "${VIM_SRC_VIM_DIR}"
  cd "${VIM_SRC_VIM_DIR}"
fi
VIM_LATEST_VER="$(git describe --tags)"
if [[ "${VIM_CURRENT_VER}" != "${VIM_LATEST_VER}" ]] || [[ ${FORCE} -eq 1 ]]; then
  make distclean
  git checkout "${VIM_LATEST_VER}"
  ./configure \
    --prefix="${VIM_DIR}" \
    --enable-fail-if-missing \
    --enable-luainterp \
    --enable-python3interp \
    --enable-cscope \
    --enable-terminal \
    --enable-multibyte \
    --enable-fontset \
    --enable-largefile \
    --with-features=huge \
    "${ADD_VIM_CONFIGURE_ARGS[@]}"
  if make; then
    make install
    echo "${VIM_LATEST_VER}" | tee "${VIM_VER_TXT}"
    cp -a "${VIM_SRC_ILV_DIR}/install_latest_vim.sh" "${VIM_DIR}/bin"
  else
    make distclean && exit 1
  fi
fi

# Dein
if [[ ${INSTALL_DEIN} -eq 1 ]]; then
  VIM_BUNDLE_DIR="${DEFAULT_VIM_DIR}/bundles"
  DEIN_VIM_DIR="${VIM_BUNDLE_DIR}/repos/github.com/Shougo/dein.vim"
  VIM_PLUGIN_UPDATE="${VIM_DIR}/bin/vim-plugin-update"
  if [[ -d "${DEIN_VIM_DIR}" ]]; then
    cd "${DEIN_VIM_DIR}"
    if [[ ${FORCE} -eq 0 ]]; then
      git pull --prune
    else
      git fetch --prune && git reset --hard origin/master
    fi
  else
    git clone https://github.com/Shougo/dein.vim "${DEIN_VIM_DIR}"
  fi
  "${DEIN_VIM_DIR}/bin/installer.sh" "${VIM_BUNDLE_DIR}"
  if [[ -f "${VIMRC}" ]]; then
    if [[ ! -f "${VIM_PLUGIN_UPDATE}" ]] || [[ ${FORCE} -eq 1 ]]; then
      {
        echo '#!/usr/bin/env bash'
        echo
        echo 'set -eux'
        echo
        echo "${VIM_DIR}/bin/vim \\"
        echo "  -c 'try | call dein#update() | finally | qall! | endtry' \\"
        echo "  -N -u ${VIMRC} -U NONE -i NONE -V1 -e -s"
      } > "${VIM_PLUGIN_UPDATE}"
      chmod +x "${VIM_PLUGIN_UPDATE}"
    fi
    "${VIM_PLUGIN_UPDATE}" || :
  fi
fi

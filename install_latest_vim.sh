#!/usr/bin/env bash
#
# Build and install the latest version of Vim
#
# Usage:
#   install_latest_vim.sh [--debug] [-f|--force] [--lua] [--dein]
#     [--vimrc=<path>] [--python3=<path>] [<dir>]
#   install_latest_vim.sh --version
#   install_latest_vim.sh -h|--help
#
# Options:
#   --debug         Run wdebug mode
#   -f, --force     Option without an argument
#   --lua           Install Lua
#   --dein          Install dein.vim
#   --vimrc=<path>  Specify a path to vimrc [default: ~/.vimrc]
#   --python3=<path>
#                   Specify a path to Python3
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
COMMAND_VER='v0.2.0'

FORCE=0
INSTALL_LUA=0
INSTALL_DEIN=0
DEFAULT_VIM_DIR="${HOME}/.vim"
VIMRC="${HOME}/.vimrc"
PYTHON3=''
MAIN_ARGS=()

function print_version {
  echo "${COMMAND_NAME}: ${COMMAND_VER}"
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
    '--python3' )
      PYTHON3="${2}" && shift 2
      ;;
    --python3=* )
      PYTHON3="${1#*\=}" && shift 1
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
VIM_BIN_DIR="${VIM_DIR}/bin"
VIM_SRC_DIR="${VIM_DIR}/src"
VIM_VER_TXT="${VIM_DIR}/VERSION.txt"
VIM_SRC_VIM_DIR="${VIM_SRC_DIR}/vim"
if [[ -z "${PYTHON3}" ]]; then
  if [[ -f '/opt/homebrew/bin/python3' ]]; then
    PYTHON3='/opt/homebrew/bin/python3'
  elif [[ -f '/usr/local/bin/python3' ]]; then
    PYTHON3='/usr/local/bin/python3'
  elif [[ -f '/usr/bin/python3' ]]; then
    PYTHON3='/usr/bin/python3'
  else
    PYTHON3="$(which python3)"
  fi
fi

[[ "${OSTYPE}" != 'msys' ]] || git config --global core.autocrlf false
[[ -d "${VIM_BIN_DIR}" ]] || mkdir -p "${VIM_BIN_DIR}"
[[ -d "${VIM_SRC_DIR}" ]] || mkdir -p "${VIM_SRC_DIR}"

# install-latest-vim
VIM_SRC_ILV_DIR="${VIM_SRC_DIR}/install-latest-vim"
if [[ -d "${VIM_SRC_ILV_DIR}/.git" ]]; then
  cd "${VIM_SRC_ILV_DIR}"
  if [[ ${FORCE} -eq 0 ]]; then
    git pull --prune
  else
    git fetch --prune && git reset --hard origin/master
  fi
else
  git clone --depth 1 https://github.com/dceoy/install-latest-vim.git "${VIM_SRC_ILV_DIR}"
fi
cp -a "${VIM_SRC_ILV_DIR}/install_latest_vim.sh" "${VIM_BIN_DIR}"

# Lua
if [[ ${INSTALL_LUA} -eq 0 ]]; then
  if lua -v; then
    ADD_VIM_CONFIGURE_ARGS=('--enable-luainterp' "--with-lua-prefix=$(which lua | xargs dirname | xargs dirname)")
  else
    ADD_VIM_CONFIGURE_ARGS=()
  fi
else
  ADD_VIM_CONFIGURE_ARGS=('--enable-luainterp' "--with-lua-prefix=${VIM_DIR}")
  LUA_FTP_URL='https://www.lua.org/ftp'
  LUA_WITH_VER=$(curl -sSL "${LUA_FTP_URL}" | grep -oe 'lua-[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
  VIM_SRC_LUA_DIR="${VIM_SRC_DIR}/lua"
  if [[ ! -d "${VIM_SRC_LUA_DIR}" ]] || [[ ${FORCE} -eq 1 ]]; then
    if [[ -d "${VIM_SRC_LUA_DIR}" ]]; then
      cd "${VIM_SRC_LUA_DIR}"
      make clean && cd .. && rm -rf "${VIM_SRC_LUA_DIR}"
      find "${VIM_BIN_DIR}" -type f -name 'lua*.dll' -exec rm -f {} \;
    fi
    if [[ -d "${VIM_SRC_DIR}/${LUA_WITH_VER}" ]]; then
      rm -rf "${VIM_SRC_DIR:?}/${LUA_WITH_VER}"
    fi
    curl -sSL -o "${VIM_SRC_DIR}/lua.tar.gz" "${LUA_FTP_URL}/${LUA_WITH_VER}.tar.gz"
    tar xvf "${VIM_SRC_DIR}/lua.tar.gz" -C "${VIM_SRC_DIR}" \
      && rm -f "${VIM_SRC_DIR}/lua.tar.gz" \
      && mv "${VIM_SRC_DIR}/${LUA_WITH_VER}" "${VIM_SRC_LUA_DIR}"
    cd "${VIM_SRC_LUA_DIR}"
    if [[ "${OSTYPE}" = 'msys' ]] && make mingw || make all test; then
      make install INSTALL_TOP="${VIM_DIR}"
      find "${VIM_SRC_LUA_DIR}" -type f -name 'lua*.dll' \
        -exec cp -an {} "${VIM_BIN_DIR}" \;
    else
      make clean && cd .. && rm -rf "${VIM_SRC_LUA_DIR}" && exit 1
    fi
  fi
fi

# Vim
VIM_CURRENT_VER="$([[ -f "${VIM_VER_TXT}" ]] && cat "${VIM_VER_TXT}" || echo -n)"
VIM_LATEST_VER="$(curl -sSL 'https://api.github.com/repos/vim/vim/tags' | grep -oe '"name": \+"v[0-9\.]\+' | head -1 | cut -d v -f 2)"
if [[ ! -f "${VIM_BIN_DIR}/vim" ]] || [[ "${VIM_CURRENT_VER}" != "${VIM_LATEST_VER}" ]] || [[ ${FORCE} -eq 1 ]]; then
  if [[ -d "${VIM_SRC_VIM_DIR}" ]]; then
    cd "${VIM_SRC_VIM_DIR}"
    make distclean && cd .. && rm -rf "${VIM_SRC_VIM_DIR}"
  fi
  if [[ -d "${VIM_SRC_VIM_DIR}-${VIM_LATEST_VER}" ]]; then
    rm -rf "${VIM_SRC_VIM_DIR}-${VIM_LATEST_VER}"
  fi
  curl -sSL -o "${VIM_SRC_DIR}/vim.tar.gz" \
    "https://github.com/vim/vim/archive/refs/tags/v${VIM_LATEST_VER}.tar.gz"
  tar xvf "${VIM_SRC_DIR}/vim.tar.gz" -C "${VIM_SRC_DIR}" \
    && rm -f "${VIM_SRC_DIR}/vim.tar.gz" \
    && mv "${VIM_SRC_VIM_DIR}-${VIM_LATEST_VER}" "${VIM_SRC_VIM_DIR}"
  cd "${VIM_SRC_VIM_DIR}"
  ./configure \
    --prefix="${VIM_DIR}" \
    --enable-fail-if-missing \
    --enable-python3interp=dynamic \
    --with-python3-command="${PYTHON3}" \
    --enable-cscope \
    --enable-terminal \
    --enable-multibyte \
    --enable-fontset \
    --enable-largefile \
    --with-features=huge \
    "${ADD_VIM_CONFIGURE_ARGS[@]}"
  if make; then
    make install
  else
    make distclean && cd .. && rm -rf "${VIM_SRC_VIM_DIR}" && exit 1
  fi
  echo "${VIM_LATEST_VER}" | tee "${VIM_VER_TXT}"
fi

# Dein
if [[ ${INSTALL_DEIN} -eq 1 ]]; then
  VIM_BUNDLE_DIR="${DEFAULT_VIM_DIR}/bundles"
  DEIN_DIR="${VIM_BUNDLE_DIR}/repos/github.com/Shougo/dein.vim"
  VIM_PLUGIN_UPDATE="${VIM_BIN_DIR}/vim-plugin-update"
  DEIN_INSTALLER="${VIM_BIN_DIR}/dein-installer.sh"
  if [[ -d "${DEIN_DIR}" ]]; then
    cd "${DEIN_DIR}"
    if [[ ${FORCE} -eq 0 ]]; then
      git pull --prune
    else
      git fetch --prune && git reset --hard origin/master
    fi
  else
    if [[ ! -f "${DEIN_INSTALLER}" ]] || [[ ${FORCE} -eq 1 ]]; then
      curl -fsSL -o "${DEIN_INSTALLER}" \
        https://raw.githubusercontent.com/Shougo/dein-installer.vim/master/installer.sh
      chmod +x "${DEIN_INSTALLER}"
    fi
    "${DEIN_INSTALLER}" --use-vim-config  "${VIM_BUNDLE_DIR}" || :
  fi
  if [[ -f "${VIMRC}" ]]; then
    if [[ ! -f "${VIM_PLUGIN_UPDATE}" ]] || [[ ${FORCE} -eq 1 ]]; then
      {
        echo '#!/usr/bin/env bash'
        echo
        echo 'set -eux'
        echo
        echo "${VIM_BIN_DIR}/vim \\"
        echo "  -c 'try | call dein#update() | finally | qall! | endtry' \\"
        echo "  -N -u ${VIMRC} -U NONE -i NONE -V1 -e -s"
      } > "${VIM_PLUGIN_UPDATE}"
      chmod +x "${VIM_PLUGIN_UPDATE}"
    fi
    "${VIM_PLUGIN_UPDATE}" || :
  fi
fi

#!/usr/bin/env bash
#
# Build and install the latest version of Vim
#
# Usage:
#   install_latest_vim.sh [--debug] [-f|--force] [--lua] [--cooldown=<days>]
#     [--vim-plug] [--vimrc=<path>] [--python3=<path>] [<dir>]
#   install_latest_vim.sh [--debug] --only-plugins [--cooldown=<days>]
#     [--vimrc=<path>] [<dir>]
#   install_latest_vim.sh --version
#   install_latest_vim.sh -h|--help
#
# Options:
#   --debug                   Run wdebug mode
#   -f, --force               Option without an argument
#   --lua                     Install Lua
#   --cooldown=<days>         Require Vim releases and GitHub plugin revisions to be at least
#                             this many days old [default: 7]
#   --vim-plug                Install vim-plug
#   --only-plugins            Update Vim plugins and exit
#   --vimrc=<path>            Specify a path to vimrc [default: ~/.vimrc]
#   --python3=<path>          Specify a path to Python3
#   --version                 Print version
#   -h, --help                Print usage
#
# Arguments:
#   <dir>                     Directory path where Vim is installed [default: ~/.vim]

set -euo pipefail

if [[ ${#} -ge 1 ]]; then
  for a in "${@}"; do
    [[ "${a}" = '--debug' ]] && set -x && break
  done
fi

COMMAND_PATH=$(realpath "${0}")
COMMAND_NAME=$(basename "${COMMAND_PATH}")
COMMAND_VER='v0.4.0'

FORCE=0
INSTALL_LUA=0
INSTALL_VIM_PLUG=0
UPDATE_VIM_PLUGINS=0
DEFAULT_VIM_DIR="${HOME}/.vim"
COOLDOWN_DAYS=7
VIM_PLUG_UPDATE_NAME='vim_plug_update.sh'
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

function github_api {
  (
    set +x
    local auth=()
    [[ -z "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]] \
      || auth=(-H "Authorization: Bearer ${GITHUB_TOKEN:-${GH_TOKEN}}")
    curl -fsSL -H 'Accept: application/vnd.github+json' "${auth[@]}" "${1}"
  )
}

function github_commit_before {
  github_api "https://api.github.com/repos/${1}/commits?until=${CUTOFF_ISO}&per_page=1" \
    | jq -er '.[0].sha'
}

function github_tag_date {
  local repository="${1}" tag="${2}" sha="${3}" ref type object tag_object
  ref="$(github_api "https://api.github.com/repos/${repository}/git/ref/tags/${tag}")"
  type="$(jq -r '.object.type' <<< "${ref}")"
  object="$(jq -r '.object.sha' <<< "${ref}")"
  case "${type}" in
    tag)
      tag_object="$(github_api "https://api.github.com/repos/${repository}/git/tags/${object}")"
      [[ "$(jq -r '.object.type' <<< "${tag_object}")" = 'commit' ]] \
        && [[ "$(jq -r '.object.sha' <<< "${tag_object}")" = "${sha}" ]] \
        || abort "tag target changed or is not a commit: ${repository} ${tag}"
      jq -er '.tagger.date' <<< "${tag_object}"
      ;;
    commit)
      [[ "${object}" = "${sha}" ]] || abort "tag target changed: ${repository} ${tag}"
      github_api "https://api.github.com/repos/${repository}/commits/${sha}" \
        | jq -er '.commit.committer.date'
      ;;
    *)
      abort "unsupported tag object type: ${repository} ${tag}"
      ;;
  esac
}

function resolve_vim_version {
  local page=1 tags tag sha date
  while :; do
    tags="$(github_api "https://api.github.com/repos/vim/vim/tags?per_page=100&page=${page}")"
    (( $(jq 'length' <<< "${tags}") > 0 )) || abort 'no Vim release is old enough'
    while IFS=$'\t' read -r tag sha; do
      date="$(github_tag_date 'vim/vim' "${tag}" "${sha}")"
      if [[ "${date}" < "${CUTOFF_ISO}" || "${date}" = "${CUTOFF_ISO}" ]]; then
        printf '%s\t%s\n' "${tag#v}" "${sha}"
        return
      fi
    done < <(jq -r '.[] | [.name, .commit.sha] | @tsv' <<< "${tags}")
    ((page++))
  done
}

function update_vim_plugins {
  local vim_plug_vim="${VIM_DIR}/autoload/plug.vim" pins repository name sha status

  [[ -f "${VIMRC}" ]] || abort "vimrc not found: ${VIMRC}"
  [[ -x "${VIM_BIN_DIR}/vim" ]] || abort "vim not found or not executable: ${VIM_BIN_DIR}/vim"

  curl -fSL --create-dirs -o "${vim_plug_vim}" \
    "https://raw.githubusercontent.com/junegunn/vim-plug/$(github_commit_before 'junegunn/vim-plug')/plug.vim"

  pins="$(mktemp "${TMPDIR:-/tmp}/vim-plug-pins.XXXXXX")"
  while read -r repository; do
    name="${repository##*/}"
    sha="$(github_commit_before "${repository}")"
    printf "if has_key(g:plugs, '%s')\n  let g:plugs['%s'].commit = '%s'\nendif\n" \
      "${name}" "${name}" "${sha}"
  done < <(
    sed -nE "s/^[[:space:]]*Plug[[:space:]]+'([[:alnum:]_.-]+\/[[:alnum:]_.-]+)'[[:space:]]*(\".*)?$/\1/p" \
      "${VIMRC}" | LC_ALL=C sort -u
  ) > "${pins}"

  "${VIM_BIN_DIR}/vim" -N -u "${VIMRC}" -U NONE -i NONE -e -s \
    -S "${pins}" -c 'PlugUpdate --sync | qa' || {
    status=$?
    rm -f "${pins}"
    return "${status}"
  }
  rm -f "${pins}"
}

function write_vim_plugin_update {
  [[ -f "${VIMRC}" ]] || return 1
  printf '#!/usr/bin/env bash\nexec %q --only-plugins --cooldown=%q --vimrc=%q %q "$@"\n' \
    "${VIM_INSTALLER}" "${COOLDOWN_DAYS}" "${VIMRC}" "${VIM_DIR}" > "${VIM_PLUG_UPDATE}"
  chmod +x "${VIM_PLUG_UPDATE}"
}

function absolute_path {
  if [[ "${1}" = /* ]] || {
    [[ "${OSTYPE}" = msys* || "${OSTYPE}" = cygwin* ]] && [[ "${1}" = [[:alpha:]]:/* ]]
  }; then
    printf '%s\n' "${1}"
  else
    printf '%s/%s\n' "${PWD}" "${1}"
  fi
}

while [[ ${#} -ge 1 ]]; do
  case "${1}" in
    '--debug')
      shift 1
      ;;
    '-f' | '--force')
      FORCE=1 && shift 1
      ;;
    '--lua')
      INSTALL_LUA=1 && shift 1
      ;;
    '--cooldown')
      [[ ${#} -ge 2 ]] || abort 'option requires an argument: --cooldown'
      COOLDOWN_DAYS="${2}" && shift 2
      ;;
    --cooldown=*)
      COOLDOWN_DAYS="${1#*=}" && shift 1
      ;;
    '--vim-plug')
      INSTALL_VIM_PLUG=1 && shift 1
      ;;
    '--only-plugins')
      UPDATE_VIM_PLUGINS=1 && shift 1
      ;;
    '--vimrc')
      VIMRC="${2}" && shift 2
      ;;
    --vimrc=*)
      VIMRC="${1#*\=}" && shift 1
      ;;
    '--python3')
      PYTHON3="${2}" && shift 2
      ;;
    --python3=*)
      PYTHON3="${1#*\=}" && shift 1
      ;;
    '--version')
      print_version && exit 0
      ;;
    '-h' | '--help')
      print_usage && exit 0
      ;;
    -*)
      abort "invalid option: ${1}"
      ;;
    *)
      MAIN_ARGS+=("${1}") && shift 1
      ;;
  esac
done

[[ "${COOLDOWN_DAYS}" =~ ^[0-9]+$ ]] || abort "invalid cooldown: ${COOLDOWN_DAYS}"
command -v jq > /dev/null || abort 'jq not found'
CUTOFF_ISO="$(date -u -v-"${COOLDOWN_DAYS}"d '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null \
  || date -u -d "${COOLDOWN_DAYS} days ago" '+%Y-%m-%dT%H:%M:%SZ')"

if [[ ${#MAIN_ARGS[@]} -gt 0 ]]; then
  VIM_DIR="${MAIN_ARGS[0]}"
else
  VIM_DIR="${DEFAULT_VIM_DIR}"
fi
VIM_DIR="$(absolute_path "${VIM_DIR}")"
VIMRC="$(absolute_path "${VIMRC}")"
VIM_BIN_DIR="${VIM_DIR}/bin"
VIM_PLUG_UPDATE="${VIM_BIN_DIR}/${VIM_PLUG_UPDATE_NAME}"
VIM_SRC_DIR="${VIM_DIR}/src"
VIM_VER_TXT="${VIM_DIR}/VERSION.txt"
VIM_SRC_VIM_DIR="${VIM_SRC_DIR}/vim"

[[ -d "${VIM_BIN_DIR}" ]] || mkdir -p "${VIM_BIN_DIR}"
VIM_INSTALLER="$(realpath "${VIM_BIN_DIR}")/install_latest_vim.sh"

if [[ ${UPDATE_VIM_PLUGINS} -eq 1 ]]; then
  [[ "${COMMAND_PATH}" = "${VIM_INSTALLER}" ]] || cp -a "${COMMAND_PATH}" "${VIM_INSTALLER}"
  write_vim_plugin_update || abort "vimrc not found: ${VIMRC}"
  update_vim_plugins
  exit 0
fi

if [[ -z "${PYTHON3}" ]]; then
  if [[ -f '/opt/homebrew/bin/python3' ]]; then
    PYTHON3='/opt/homebrew/bin/python3'
  elif [[ -f '/usr/local/bin/python3' ]]; then
    PYTHON3='/usr/local/bin/python3'
  elif [[ -f '/usr/bin/python3' ]]; then
    PYTHON3='/usr/bin/python3'
  else
    PYTHON3="$(command -v python3)"
  fi
fi

[[ -d "${VIM_SRC_DIR}" ]] || mkdir -p "${VIM_SRC_DIR}"

# install-latest-vim
[[ "${COMMAND_PATH}" = "${VIM_INSTALLER}" ]] || cp -a "${COMMAND_PATH}" "${VIM_INSTALLER}"

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
VIM_LATEST_INFO="$(resolve_vim_version)"
IFS=$'\t' read -r VIM_LATEST_VER VIM_LATEST_SHA <<< "${VIM_LATEST_INFO}"
if [[ ! -f "${VIM_BIN_DIR}/vim" ]] || [[ "${VIM_CURRENT_VER}" != "${VIM_LATEST_VER}" ]] || [[ ${FORCE} -eq 1 ]]; then
  if [[ -d "${VIM_SRC_VIM_DIR}" ]]; then
    cd "${VIM_SRC_VIM_DIR}"
    make distclean && cd .. && rm -rf "${VIM_SRC_VIM_DIR}"
  fi
  VIM_SRC_VIM_ARCHIVE_DIR="${VIM_SRC_DIR}/vim-${VIM_LATEST_SHA}"
  if [[ -d "${VIM_SRC_VIM_ARCHIVE_DIR}" ]]; then
    rm -rf "${VIM_SRC_VIM_ARCHIVE_DIR}"
  fi
  curl -sSL -o "${VIM_SRC_DIR}/vim.tar.gz" \
    "https://github.com/vim/vim/archive/${VIM_LATEST_SHA}.tar.gz"
  tar xvf "${VIM_SRC_DIR}/vim.tar.gz" -C "${VIM_SRC_DIR}" \
    && rm -f "${VIM_SRC_DIR}/vim.tar.gz" \
    && mv "${VIM_SRC_VIM_ARCHIVE_DIR}" "${VIM_SRC_VIM_DIR}"
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

# vim-plug
if [[ ${INSTALL_VIM_PLUG} -eq 1 ]]; then
  if write_vim_plugin_update; then
    "${VIM_PLUG_UPDATE}" || :
  fi
fi

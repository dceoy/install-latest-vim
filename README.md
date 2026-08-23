# install-latest-vim

Installer for the latest version of Vim

[![CI/CD](https://github.com/dceoy/install-latest-vim/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/install-latest-vim/actions/workflows/ci.yml)

## Usage

1.  Download `install_latest_vim.sh`.

    ```sh
    $ curl -SLO https://raw.githubusercontent.com/dceoy/install-latest-vim/master/install_latest_vim.sh
    $ chmod +x install_latest_vim.sh
    ```

2.  Build and install Vim.

    Vim releases, vim-plug, and simple GitHub plugins (`Plug 'owner/repo'`) must be at least 7 days old by default. Set `--cooldown=0` to disable the cooldown. Plugin entries with options and non-GitHub plugins keep their existing vim-plug behavior.

    Install Vim into `~/.vim/bin/vim`.

    ```sh
    $ ./install_latest_vim.sh
    ```

    Install Vim with Lua.

    ```sh
    $ ./install_latest_vim.sh --lua
    ```

    Install Vim into a custom directory (`/path/to/dir/bin/vim`).

    ```sh
    $ ./install_latest_vim.sh /path/to/dir
    ```

    Use a 14-day cooldown.

    ```sh
    $ ./install_latest_vim.sh --cooldown=14 --vim-plug
    ```

    Update Vim plugins without rebuilding Vim.

    ```sh
    $ ./install_latest_vim.sh --only-plugins
    ```

Cooldown checks require `jq`. GitHub API lookups use `GITHUB_TOKEN` or `GH_TOKEN` when available.

Run `./install_latest_vim.sh --help` for more information.

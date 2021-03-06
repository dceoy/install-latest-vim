install-latest-vim
==================

Installer for the latest version of Vim

Usage
-----

1.  Download `install_latest_vim.sh`.

    ```sh
    $ curl -SLO https://raw.githubusercontent.com/dceoy/install-latest-vim/master/install_latest_vim.sh
    $ chmod +x install_latest_vim.sh
    ```

2.  Build and install Vim.

    Install Vim into `~/.vim/bin/vim`.

    ```sh
    $ ./install_latest_vim.sh
    ```

    Install Vim into a custom directory (`/path/to/dir/bin/vim`).

    ```sh
    $ ./install_latest_vim.sh /path/to/dir
    ```

Run `./install_latest_vim.sh --help` for more information.

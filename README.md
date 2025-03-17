install-latest-vim
==================

Installer for the latest version of Vim

[![CI to Docker Hub](https://github.com/dceoy/install-latest-vim/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/install-latest-vim/actions/workflows/ci.yml)

Docker image
------------

Pull the image from [Docker Hub](https://hub.docker.com/r/dceoy/vim/).

```sh
$ docker image pull dceoy/vim
```

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

    Install Vim with Lua.

    ```sh
    $ ./install_latest_vim.sh --lua
    ```

    Install Vim into a custom directory (`/path/to/dir/bin/vim`).

    ```sh
    $ ./install_latest_vim.sh /path/to/dir
    ```

Run `./install_latest_vim.sh --help` for more information.

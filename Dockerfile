FROM ubuntu:latest

ENV DEBIAN_FRONTEND noninteractive

ADD https://bootstrap.pypa.io/get-pip.py /tmp/get-pip.py
ADD https://raw.githubusercontent.com/dceoy/ansible-dev/master/roles/vim/files/vimrc /root/.vimrc
ADD install_latest_vim.sh /tmp/install_latest_vim.sh

RUN set -e \
      && ln -sf bash /bin/sh \
      && ln -s python3 /usr/bin/python

RUN set -e \
      && apt-get -y update \
      && apt-get -y dist-upgrade \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        apt-transport-https apt-utils ca-certificates curl gcc git libc6-dev \
        libncurses-dev make python3-dev python3-distutils shellcheck \
      && apt-get -y autoremove \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/*

RUN set -e \
      && /usr/bin/python3 /tmp/get-pip.py \
      && pip install -U --no-cache-dir pip \
      && pip install -U --no-cache-dir \
        ansible-lint autopep8 flake8 flake8-bugbear flake8-isort pep8-naming \
        vim-vint yamllint

RUN set -e \
      && chmod +x /tmp/install_latest_vim.sh \
      && /tmp/install_latest_vim.sh --debug --lua --dein /usr/local

ENTRYPOINT ["/usr/local/bin/vim"]

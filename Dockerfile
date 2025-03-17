# syntax=docker/dockerfile:1
ARG UBUNTU_VERSION=24.04
FROM public.ecr.aws/docker/library/ubuntu:${UBUNTU_VERSION} AS builder

ARG PYTHON_VERSION=3.13

ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1
ENV POETRY_HOME=/opt/poetry
ENV POETRY_VIRTUALENVS_CREATE=false
ENV POETRY_NO_INTERACTION=true

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN \
      rm -f /etc/apt/apt.conf.d/docker-clean \
      && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
        > /etc/apt/apt.conf.d/keep-cache

# hadolint ignore=DL3008
RUN \
      --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      apt-get -y update \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        software-properties-common \
      && add-apt-repository ppa:deadsnakes/ppa

# hadolint ignore=DL3008
RUN \
      --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      apt-get -y update \
      && apt-get -y upgrade \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        ca-certificates curl gcc git libc6-dev libncurses-dev make \
        "python${PYTHON_VERSION}-dev"

RUN \
      --mount=type=cache,target=/root/.cache \
      ln -s "python${PYTHON_VERSION}" /usr/bin/python \
      && curl -SL -o /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py \
      && /usr/bin/python /tmp/get-pip.py \
      && rm -f /tmp/get-pip.py

RUN \
      curl -SL -o /root/.vimrc \
        https://raw.githubusercontent.com/dceoy/ansible-dev-server/refs/heads/master/roles/vim/files/vimrc

RUN \
      --mount=type=cache,target=/root/.cache \
      --mount=type=bind,source=.,target=/mnt/host \
      cp -a /mnt/host/install_latest_vim.sh /usr/local/bin/install_latest_vim.sh \
      && /usr/local/bin/install_latest_vim.sh \
        --lua --python3="/usr/bin/python${PYTHON_VERSION}" --vimrc=/root/.vimrc --vim-plug \
        /usr/local


FROM public.ecr.aws/docker/library/ubuntu:${UBUNTU_VERSION} AS cli

ARG PYTHON_VERSION=3.13
ARG USER_NAME=cli
ARG USER_UID=1001
ARG USER_GID=1001

COPY --from=builder /usr/local /usr/local
COPY --from=builder /etc/apt/apt.conf.d/keep-cache /etc/apt/apt.conf.d/keep-cache
COPY --from=builder /root/.vimrc /root/.vimrc

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN \
      ln -s "python${PYTHON_VERSION}" /usr/bin/python \
      && rm -f /etc/apt/apt.conf.d/docker-clean

# hadolint ignore=DL3008
RUN \
      --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      apt-get -y update \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        software-properties-common \
      && add-apt-repository ppa:deadsnakes/ppa

# hadolint ignore=DL3008
RUN \
      --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt,sharing=locked \
      apt-get -y update \
      && apt-get -y upgrade \
      && apt-get -y install --no-install-recommends --no-install-suggests \
        ca-certificates curl git "python${PYTHON_VERSION}"

RUN \
      groupadd --gid "${USER_GID}" "${USER_NAME}" \
      && useradd --uid "${USER_UID}" --gid "${USER_GID}" --shell /bin/bash --create-home "${USER_NAME}"

RUN \
      cp -a /root/.vimrc "/home/${USER_NAME}/.vimrc" \
      && chown "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}/.vimrc"

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

HEALTHCHECK NONE

ENTRYPOINT ["/usr/local/bin/vim"]

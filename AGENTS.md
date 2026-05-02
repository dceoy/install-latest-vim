# Repository Guidelines

## Project Structure & Module Organization

This repository packages an installer for the latest Vim release and a Docker image
that runs it. The main entry point is `install_latest_vim.sh` in the repository
root. Docker build configuration lives in `Dockerfile` and `compose.yml`. CI and
dependency automation are under `.github/`. Agent and local QA support files are
under `.agents/`. There is no separate source, test, or asset tree; keep new
project files close to the root unless a new category clearly needs its own
directory.

## Build, Test, and Development Commands

- `./install_latest_vim.sh --help`: show supported installer flags and arguments.
- `./install_latest_vim.sh [--lua] [--vim-plug] [<install_dir>]`: build and install
  Vim locally, defaulting to `~/.vim`.
- `./install_latest_vim.sh --only-plugins`: update Vim plugins without rebuilding
  Vim.
- `./install_latest_vim.sh --version`: print the installer version.
- `docker compose build vim`: build the local Docker image from `Dockerfile`.
- `docker compose run --rm vim`: run the built image and print Vim version output.
- `.agents/skills/local-qa/scripts/qa.sh`: run repository QA checks.

### Code Quality and Documentation

**Important**: Run QA using `local-qa` skill before committing or creating a PR.

## Coding Style & Naming Conventions

Use Bash with `set -euo pipefail`. Prefer lowercase `underscore_case` function
names, uppercase globals, and lowercase local variables. Quote variable expansions
as `"${VAR}"` and route fatal errors through the existing `abort` helper pattern.
Use 2-space indentation for shell scripts, Dockerfiles, YAML, and Markdown lists.
Keep script usage comments complete when adding or changing CLI flags.

## Testing Guidelines

There is no dedicated unit test suite. Validate shell changes with `shellcheck` and
exercise affected CLI paths, for example `./install_latest_vim.sh --help` and
`./install_latest_vim.sh --version`. Validate Docker-related changes with
`docker compose build vim` when practical. Run `.agents/skills/local-qa/scripts/qa.sh`
before handing off changes; it applies Markdown formatting and checks shell,
GitHub Actions, YAML, infrastructure, and security configuration.

## Commit & Pull Request Guidelines

Recent history uses short imperative subject lines such as `Add update_vim_plugins.sh`
and `Replace dein.vim with vim-plug`. Follow that style: one concise subject,
capitalized verb, no trailing period. Pull requests should describe the behavior
change, list validation commands run, link related issues when available, and note
Docker or CI implications for changes to `Dockerfile`, `compose.yml`, or `.github/`.

## Agent-Specific Instructions

Preserve unrelated worktree changes. Do not rewrite generated automation files unless
the task requires it, and keep documentation updates concise and command-oriented.

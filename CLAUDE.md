# CLAUDE.md - Agent Guidance for install-latest-vim

## Build & Docker Commands
- Build local Vim: `./install_latest_vim.sh [--lua] [--vim-plug] [--debug] [<install_dir>]`
- Run Docker image: `docker compose run --rm vim`
- Build Docker image: `docker buildx bake`
- Check Vim version: `./install_latest_vim.sh --version`

## Code Style Guidelines
- Shell scripting: Use `set -euo pipefail` for error handling
- Functions: Lowercase with underscore_case
- Variables: UPPERCASE for global, lowercase for local scope
- Quote all variable expansions: `"${VAR}"`
- Indentation: 2 spaces for shell scripts, Dockerfiles and YAML
- Error handling: Use the `abort` function for failures
- Input validation: Validate arguments and provide helpful error messages
- Docker: Follow Dockerfile best practices with clear ARGs and multi-stage builds

## Documentation Standards
- Shell scripts: Include complete usage info in header comments
- Include examples in README.md for common use cases
- Maintain version numbers in scripts and update on changes
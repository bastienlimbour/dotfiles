# AGENTS.md

This repository is a chezmoi-managed dotfiles source tree.

Most content is:

- Chezmoi source state under `home/` (`dot_*`, `private_*`, `executable_*`, etc.)
- Go templates rendered by chezmoi (`*.tmpl`, `*.toml.tmpl`, `*.sh.tmpl`)
- Shell scripts executed by chezmoi triggers (`run_onchange_*`)

Agents working here should optimize for: idempotent changes, safe defaults, minimal side
effects, and easy review.

## Repo Layout (Chezmoi)

- `home/` is the source root (see `.chezmoiroot`)
- Name mapping (important):
  - `home/dot_zshrc.tmpl` -> `~/.zshrc`
  - `home/dot_config/git/config.tmpl` -> `~/.config/git/config`
  - `home/private_*` -> restrictive permissions on target
  - `home/executable_*` -> executable on target

## Build / Lint / Test Commands

There is no conventional test suite. Validation is mostly:

- render templates
- shell syntax checks
- inspect the diff that chezmoi would apply

**Core validation (recommended)**:

- See what would change:
  - `chezmoi diff`
  - `chezmoi status`

- Validate render + apply plan (no changes applied):
  - `chezmoi apply --dry-run --verbose`

- Validate config health:
  - `chezmoi doctor`

**"Run a single test" equivalents**:

Pick the smallest unit affected by your change and validate just that:

- Render a template to stdout:
  - `chezmoi execute-template < home/dot_config/git/config.tmpl`

- Render a shell template and syntax-check it:

  ```bash
  chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_10-install-packages.sh.tmpl > /tmp/chezmoi-script.sh
  bash -n /tmp/chezmoi-script.sh
  ```

- Syntax-check a repo script (non-template):
  - `bash -n home/Dev/Scripts/executable_start-php-services.sh`

- Optional shell lint (only if installed):
  - `shellcheck /tmp/chezmoi-script.sh`

**Applying changes (interactive side effects)**:

- Apply for real (may run `run_onchange_*` scripts that prompt / install / mutate system):
  - `chezmoi apply`

If you are an agent, prefer `--dry-run` unless explicitly asked to apply.

## Code Style Guidelines

### General

- Keep diffs small and focused; avoid unrelated refactors across dotfiles.
- Do not add secrets (tokens, certs, private keys). Prefer `private_*` for sensitive files.
- Prefer source-of-truth in `home/` and templates; avoid hardcoding absolute paths when a
  chezmoi variable exists.
- Preserve existing conventions in each area (zsh templates vs bash scripts vs config).

### Shell (bash) scripts

- Use:
  - Shebang: `#!/bin/bash`
  - Safety: `set -eufo pipefail`
- Quote variables by default; avoid relying on word-splitting.
- Prefer `command -v tool >/dev/null` for presence checks.
- Make scripts idempotent:
  - check current state before mutating (e.g. `brew bundle check` before `brew bundle`)
  - OK to use `|| true` only when failure is acceptable and understood (e.g. `killall`).
- Error handling:
  - fail fast when state is inconsistent
  - print actionable errors (what failed + suggested next step)

### Shell (zsh) config

- `home/dot_zshrc.tmpl` sources other templates. Keep sections grouped by intent.
- Respect the `CURSOR_AGENT` guard (avoid heavy interactive UI when set).
- Avoid expensive commands on shell startup; prefer lazy-loading where possible.

### Chezmoi templates (Go templates)

- Prefer readability over clever one-liners.
- Use whitespace-trimming delimiters where it improves output:
  - `{{- ... -}}`
- Avoid repeating complex expressions; bind to variables:
  - `{{- $hostname := ... -}}`
- When emitting config values (TOML/INI-ish), prefer explicit quoting:
  - `{{ $value | quote }}`
- Avoid embedding secrets; prompt via chezmoi or reference external secret stores.

### JSON / TOML / INI-ish files

- Match existing formatting.
- JSON: 2-space indentation; keep trailing commas only if the file already uses them.
- TOML: keep sections shallow; prefer descriptive keys.

### Git config templates

- Templates live in:
  - `home/dot_config/git/config.tmpl`
  - `home/dot_config/git/config.work.tmpl`
- Prefer `includeIf` instead of duplicating config blocks.
- Do not change defaults (`init.defaultBranch = main`, `pull.rebase = true`) without reason.

### Naming conventions

- Scripts under `home/Dev/Scripts/`:
  - use `executable_<kebab-name>.sh`
  - keep behavior focused; add usage/help text if non-obvious
- Chezmoi hooks:
  - `home/.chezmoiscripts/run_onchange_after_<nn>-<topic>.sh.tmpl` (keep numbering stable)

## Review Checklist

- `chezmoi diff` shows only intended changes
- templates render (`chezmoi execute-template`) and scripts pass `bash -n`
- changes are safe to re-run (idempotent)
- no secrets or private identifiers added

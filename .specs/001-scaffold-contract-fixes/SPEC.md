# Feature: scaffold-contract-fixes

## Overview

The scaffold-hardening work (`.specs/scaffold-hardening/`, commit `d0a06db`, 2026-04-18) added the template purge, the host-port prefix and the Docker-provider Vagrantfile. Its end-to-end check (plan task 19) was never recorded as run, and the one scaffold made after it landed (2026-04-20) shows that parts of it do not work. This spec fixes seven defects in what was landed, gives each one a check that runs without tokens or network, and pins the Claude Code version so behaviour stops changing between image builds.

It changes prompts, skills, one new check script, the entrypoint's launch command and one Ansible default. It does not restructure the pipeline; `002-resumable-pipeline` does that and builds on the fixes here.

**Enables:** 002 (uses `poiesis-purge-check` as a stage gate and the env-delivered settings), 005 (uses the image namespace).

## Evidence

Confirmed on 2026-11-21 against the locally built `svanosselaer/poiesis-service:arm64` (entrypoint bypassed), the template checkouts in `tmp/`, and the repositories the 2026-04-20 run left on GitHub.

| # | Defect | Where | How it was confirmed |
|---|---|---|---|
| D1 | The scaffolder cannot read the port prefix. Prompts and `scaffold-services` name the workspace `AGENTS.md` as the source of truth and forbid reading the environment. Claude Code runs as `claude` with `HOME=/home/claude`; the file is under `/root`, mode `700`. | `prompts/monitor-and-scaffold.md` (Environment), `prompts/scaffold-project.md` (intro), `skills/scaffold-services/SKILL.md` step 1 | In the image: `stat -c %a /root` → `700`; `runuser -u claude -- ls /root/.openclaw/workspace/AGENTS.md` → `Permission denied` |
| D2 | The frontend purge deletes the template name instead of renaming it: `sed -i -E 's/www-qual-is//g; s/qual\.is//g'`. The rename step covers Python services only. | `skills/purge-template/SKILL.md`, recipe `www-qual-is` | `svo/intent-based-api-ui` after its purge commit: `package.json` has `"name": ""`; `service.pkr.hcl` has `source "docker" "-service"` and `repository = "svanosselaer/-service"`; `build.sh` runs `svanosselaer/-builder:latest` |
| D3 | The purge verification for `application.properties` never fires: `fgrep -rn -E 'host=.+port='` exits 2 (`grep: conflicting matchers specified`), stderr is discarded, and the `if` treats it as "no residue". | `skills/purge-template/SKILL.md`, recipe `python-sprint-zero` | Reproduced in the image on a file containing `host=0.0.0.0port=8000`: exit status 2 |
| D4 | The `application.properties` fix targets a state that does not exist when it runs. The template file ends `host=0.0.0.0` with no trailing newline and has no `port` key. The purge runs before any editing, finds nothing to split, and the later port step appends `port=…` onto the `host` line. | Same recipe; template `src/*/resources/application.properties` | `cat -e` of the template file and of `svo/intent-based-api-api-server` after purge and rename: last line `host=0.0.0.0`, no `$` |
| D5 | Skills the prompts tell Claude Code to run cannot be invoked by the model: `purge-template`, `specify`, `plan` and `scaffold-services` carry `disable-model-invocation: true`. The documented behaviour is a refusal plus an instruction not to reproduce the steps another way. | Frontmatter of the four `SKILL.md` files | Claude Code docs (skills, "Control who invokes a skill"). Observed in this repository on 2026-11-21: `Skill specify cannot be used with Skill tool due to disable-model-invocation … Do not replicate this skill's workflow by other means`. The April run did commit a purge, so an older Claude Code found another route; nothing guarantees the current one does |
| D6 | Image names use the GitHub owner as the registry namespace. Prompts set `docker-tag` and the Vagrantfile image to `${GITHUB_OWNER}/…`. The owner is `svo`; the images live under `svanosselaer`. The template already has the right namespace, so the "normalise" step would break it. | `prompts/*` (Vagrantfile and docker-tag steps), `skills/scaffold-services/SKILL.md` steps 6 and 8 | `svo/intent-based-api-api-server` after rename: `repository = "svanosselaer/intent-based-api-api-server-service"`; `tmp/consented-signal/Vagrantfile` uses `svanosselaer/…` |
| D7 | `run-service` tells the reader to `docker build -t … .` and to pass `NEXT_PUBLIC_*` variables. Neither template has a Dockerfile (images are built by Packer), and scaffold-hardening removed `NEXT_PUBLIC_*`. It also publishes ports without the prefix. | `skills/run-service/SKILL.md` | `find tmp/python-sprint-zero tmp/www-qual-is -maxdepth 2 -iname 'Dockerfile*'` → nothing |
| D8 | Claude Code is installed unpinned, so each image build can change how prompts and skills behave. OpenClaw was pinned for the same reason (README, "Pinned Versions"). | `roles/claude-code-service/tasks/main.yml`, first task | Image built 2026-11-21 has `2.1.330`; the role names no version |

## User Stories

- As the **Poiesis operator**, I want the frontend repository to keep a valid package name and valid image names after the purge so that it can be built at all.
- As the **Poiesis operator**, I want to set the image namespace separately from the GitHub owner so that generated tags point at a registry namespace I control.
- As **Claude Code acting as the scaffolder**, I want scaffold settings delivered where I can read them so that I do not fall back to guesses.
- As **Claude Code acting as the scaffolder**, I want to be able to load the skills the prompts tell me to use.
- As the **maintainer**, I want each defect to have a check that fails if it returns, runnable without tokens, so that the next hardening change is verified before it ships.
- As the **maintainer**, I want two builds of the same commit to contain the same Claude Code.

## Acceptance Criteria

### Settings reach the scaffolder (D1)

- [ ] **AC1** — Given the service image, when the cycle command from the generated `AGENTS.md` is run with `POIESIS_HOST_PORT_PREFIX=4`, then the process running as `claude` has `POIESIS_HOST_PORT_PREFIX=4` in its environment.
- [ ] **AC2** — Given the shipped prompts and skills, when they are searched, then none tells the scaffolder to read a path under `/root` or `~/.openclaw`, and none forbids reading the environment.

### Frontend rename (D2)

- [ ] **AC3** — Given a frontend submodule freshly created from `svo/www-qual-is` for project `P` and service `S`, when purge and rename have completed, then `package.json` `name` is `P-S` and the Packer `source` and `docker-tag` names contain `P-S`.
- [ ] **AC4** — Given the same submodule, when `poiesis-purge-check www-qual-is <path>` runs, then it exits 0 only if no file outside `.git` and `node_modules` contains `www-qual-is` or `qual.is`, the package name is not empty, and none of `/-service`, `/-builder` or `www./` occurs.

### Purge verification (D3, D4)

- [ ] **AC5** — Given a backend tree whose `application.properties` holds two keys on one line (`host=0.0.0.0port=8001`), when `poiesis-purge-check python-sprint-zero <path>` runs, then it exits non-zero and names the file.
- [ ] **AC6** — Given a backend submodule after the purge, when `application.properties` is inspected, then it ends with a newline.
- [ ] **AC7** — Given a backend submodule after its port has been configured, when `poiesis-purge-check` runs again, then it exits 0, and `host` and `port` are on separate lines.
- [ ] **AC8** — Given residue-free backend and frontend fixture trees, when `poiesis-purge-check` runs, then it exits 0; given a tree with any `coconut` file or reference under `src` or `tests`, then it exits non-zero.

### Skills can be loaded (D5)

- [ ] **AC9** — Given the service image, when the frontmatter of `purge-template`, `specify`, `plan` and `scaffold-services` under `/home/claude/.claude/skills/` is read, then none sets `disable-model-invocation: true`.
- [ ] **AC10** — Given the service image and valid credentials, when Claude Code is asked headlessly to run the `purge-template` skill on a fixture, then the transcript shows the skill being loaded and no refusal.

### Image namespace (D6)

- [ ] **AC11** — Given `POIESIS_GITHUB_OWNER=svo` and `POIESIS_IMAGE_NAMESPACE=svanosselaer`, when a scaffold completes, then every `docker-tag` repository and every Vagrantfile image begins `svanosselaer/`.
- [ ] **AC12** — Given `POIESIS_IMAGE_NAMESPACE` is unset, when the container starts, then the namespace defaults to the GitHub owner; given a value that is not a valid registry namespace, then the container exits non-zero and names the variable.

### run-service (D7)

- [ ] **AC13** — Given the shipped `run-service` skill, when it is read, then it starts services through the project's Vagrantfile, and contains neither `docker build` nor `NEXT_PUBLIC`.

### Reproducible Claude Code (D8)

- [ ] **AC14** — Given two builds of the same commit on different days, when `claude --version` is run in each image, then both print the version in `claude_code_version`.

### Checks

- [ ] **AC15** — Given a checkout with no network and no tokens, when `.specs/001-scaffold-contract-fixes/tests/run` is executed, then it exercises AC2, AC4, AC5, AC8, AC9 and AC13 and exits 0.
- [ ] **AC16** — Given a push or pull request, when CI runs, then it runs `shellcheck` on the shipped scripts and every `.specs/*/tests/run`.

## Surface Impact

### Claude Code configuration (`infrastructure/ansible/roles/claude-code-service/`)

- `files/prompts/monitor-and-scaffold.md`, `files/prompts/scaffold-project.md` — read the prefix and namespace from the environment; add a frontend branch to the rename step; run `poiesis-purge-check` after purge and again after port configuration; use the namespace for `docker-tag` and Vagrantfile images.
- `files/skills/purge-template/SKILL.md` — stop deleting `www-qual-is` / `qual.is`; add a trailing newline to `application.properties`; replace the inline verification with a call to `poiesis-purge-check`; drop the frontmatter flag.
- `files/skills/scaffold-services/SKILL.md` — same settings, rename and namespace changes; drop the flag.
- `files/skills/specify/SKILL.md`, `files/skills/plan/SKILL.md` — drop the flag only.
- `files/skills/run-service/SKILL.md` — rewritten around the Vagrantfile.
- New `files/bin/poiesis-purge-check` — deterministic residue check for both templates.
- `tasks/main.yml` — install the script; install Claude Code at `claude_code_version`.
- New `defaults/main.yml` — `claude_code_version`.

### Entrypoint & workspace generation (`roles/openclaw/files/entrypoint.sh`)

- Validate `POIESIS_IMAGE_NAMESPACE`.
- `AGENTS.md` heredoc: the cycle command (lines 224–228 today) passes `POIESIS_HOST_PORT_PREFIX` and `POIESIS_IMAGE_NAMESPACE` alongside the two variables it already passes; the "Scaffolding configuration" section documents both.

### OpenClaw configuration

- None beyond the heredoc above.

### Packer images

- `poiesis-service` rebuilds. No new packages.

### Build & release scripts

- New `.github/workflows/checks.yml`.
- New `.specs/001-scaffold-contract-fixes/tests/`.

### Runtime environment

- One new optional variable; one existing variable delivered differently.

## Environment & Configuration

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `POIESIS_IMAGE_NAMESPACE` | No | value of `POIESIS_GITHUB_OWNER` | Registry namespace for generated image names (`<namespace>/<project>-<service>-service`) |
| `POIESIS_HOST_PORT_PREFIX` | No | `3` | Unchanged meaning. Now passed to Claude Code in its environment rather than read from `AGENTS.md` |

`claude_code_version` (Ansible default, not an environment variable) is set to the version in the image this spec was written against: `2.1.330`.

The production container sets neither variable today (`svo-openclaw` Terraform module, `docker run … --name poiesis`). It needs `POIESIS_IMAGE_NAMESPACE=svanosselaer`.

## Scaffolding Behaviour Impact

- Frontend repositories keep a valid `package.json` name, Packer source names, image tags and build scripts, all carrying `<project>-<service>`.
- Backend `application.properties` has one key per line from the first commit that sets the port.
- Image names use the configured namespace in `service.pkr.hcl` and in the Vagrantfile.
- A scaffold that leaves residue stops at the check instead of pushing it.
- No change to when or how often scaffolding runs.

## Operational Impact

- Cron schedule, startup time, persisted state, messaging: unchanged.
- Image size: one small script.
- Bumping Claude Code becomes a deliberate change, like bumping OpenClaw.
- CI gains one workflow that needs no secrets.

## Constraints

Checked against "What Not to Build" in `.claude/CLAUDE.md`:

- Single container, single gateway: unchanged.
- "Tune behaviour through the generated workspace files": D1 moves scaffold *settings* out of `AGENTS.md` because the process that needs them cannot read it. `AGENTS.md` still documents them and still carries the command that passes them, so the behaviour is tuned in the same place. This reverses the reading of that rule made in `scaffold-hardening/PLAN.md` ("the scaffolder reads it from the workspace file, not from `process.env`").
- `poiesis-purge-check` is a deterministic check, not agent behaviour. What to purge and how to rewrite stays in the skill.
- No state outside `/root/.openclaw`; no coupling to a scaffolded project (test fixtures are synthetic).

## Open Questions

1. **How skills are invoked (D5).** Recommended: drop the flag on the four pipeline skills as shipped in the image, and restore it on the `scaffold-services` copy written into generated projects, since that skill creates repositories. Alternative: keep the flag and have the caller pass the slash command as the `-p` prompt (`claude -p "/purge-template …"`), which only becomes practical with the staged driver in 002.
2. **What replaces `qual.is` references.** Recommended: the name `www-qual-is` becomes `<project>-<service>` mechanically; every remaining `qual.is` reference (site URL, brand text, analytics, `robots.txt`) is rewritten in context by the scaffolder, never deleted by `sed`, and the check enforces that none remain. An allow-list file in the service repository covers intentional attribution.
3. **Invalid namespace: fail or warn.** Recommended: fail. `POIESIS_HOST_PORT_PREFIX` warns and falls back, but a wrong namespace silently produces images tagged for someone else's registry namespace.
4. **Pin Claude Code in the development image too.** Recommended: no. The development image is for people; only the service image runs unattended.
5. **The repositories damaged on 2026-04-20.** `svo/intent-based-api-ui` carries the D2 damage. Whether to repair or recreate it is decided in 002 (Open Question 1 there).

# Plan: scaffold-contract-fixes

Derived from: `.specs/001-scaffold-contract-fixes/SPEC.md`

## Implementation Strategy

Write the checks first and watch them fail, then fix one defect per slice. Every task is independently committable and leaves the image runnable. The order puts the deterministic check (`poiesis-purge-check`) before the prompt and skill edits that rely on it, and puts the CI workflow last so `main` is never red on the way.

Three decisions shape the work. They follow the recommended answers to the spec's open questions; change them there first if you disagree.

1. Scaffold settings travel in the environment of the Claude Code process. `AGENTS.md` keeps documenting them and carries the command that passes them.
2. The residue check is a script in the image, not prose in a skill, so it can be tested with fixtures and reused by 002 as a stage gate.
3. The four pipeline skills lose `disable-model-invocation` as shipped in the image. The copy of `scaffold-services` written into generated projects gets the flag back.

All paths below are under `infrastructure/ansible/roles/` unless they start with `.`.

## Surface Changes

### OpenClaw configuration

- No role or setting changes.

### Claude Code configuration

- `claude-code-service/files/bin/poiesis-purge-check` (new). Usage `poiesis-purge-check <python-sprint-zero|www-qual-is> <path>`. Prints one `purge-check: <file>: <reason>` line per finding on stderr; exits 1 on findings, 2 on bad usage. No `jq`; `grep`, `find`, `tail` only.
  - `python-sprint-zero`: any file named `*coconut*` or containing `coconut` (any case) under `src` or `tests`; any `src/*/resources/application.properties` line holding a second known key (`grep -nE '=.*(host|port|reload)='`); any such file not ending in a newline.
  - `www-qual-is`: any file outside `.git`, `node_modules`, `.next` and the paths listed in an optional `.purge-allow` containing `www-qual-is` or `qual.is`; `package.json` with an empty `name`; any occurrence of `/-service`, `/-builder`, `/-development` or `www./`; any of the blog paths the current recipe removes still present.
- `claude-code-service/files/skills/purge-template/SKILL.md`
  - `python-sprint-zero` recipe: replace the `sed` that splits `host=…port=` with one that guarantees a trailing newline (`sed -i -e '$a\'`); delete both inline verification blocks, including `fgrep -rn -E`; end with `poiesis-purge-check python-sprint-zero .`.
  - `www-qual-is` recipe: delete the loop that runs `sed -i -E 's/www-qual-is//g; s/qual\.is//g'` and the inline verification; end with a note that the name is handled by the rename step and that `poiesis-purge-check www-qual-is .` runs after it.
  - Frontmatter: remove `disable-model-invocation: true`.
- `claude-code-service/files/skills/scaffold-services/SKILL.md`
  - Step 1: read `POIESIS_HOST_PORT_PREFIX` (default `3`) and `POIESIS_IMAGE_NAMESPACE` (default: the GitHub owner) from the environment; remove the `~/.openclaw/workspace/AGENTS.md` instruction.
  - Rename step: add the frontend branch (below). Add an explicit instruction to write `port=<guest>` on its own line in `application.properties`.
  - Steps 6 and 8: image and `docker-tag` repository are `${IMAGE_NAMESPACE}/${PROJECT_NAME}-<service>-service`.
  - After rename and port: run `poiesis-purge-check` again.
  - Frontmatter: remove the flag.
- `claude-code-service/files/skills/specify/SKILL.md`, `…/plan/SKILL.md` — remove the flag. No other change.
- `claude-code-service/files/skills/run-service/SKILL.md` — rewrite: ports, names and environment come from the parent `Vagrantfile`; start with `vagrant up <service>` or `vagrant up`; stop with `vagrant halt <service>`; if the image is missing, say so and name the service's own build script. No `docker build`, no `NEXT_PUBLIC`.
- `claude-code-service/files/prompts/monitor-and-scaffold.md`, `…/scaffold-project.md`
  - Environment paragraph: print and use the two variables from the environment; delete "do not read it from `process.env`".
  - Rename step, frontend branch: replace `www-qual-is` with `${project}-${service}` in file contents and in file and directory names, with the same commands the Python branch uses. Then rewrite each remaining `qual.is` reference in context: site URL to a `SITE_URL` setting defaulting to `http://localhost:${PORT_PREFIX}3000`; brand text to the project title; remove the analytics script and its content-security-policy entries; make `robots.txt` disallow everything and drop its sitemap line; delete template reference notes under `.claude/skills/*/references/` that quote the blog's code. Anything kept on purpose goes in `.purge-allow`.
  - Rename step, backend branch: set `port=<guest>` on its own line.
  - After rename: `poiesis-purge-check` for every submodule, before the first push.
  - Vagrantfile and docker-tag steps: `${IMAGE_NAMESPACE}` in place of `${GITHUB_OWNER}` for image names.
  - `scaffold-project.md`, "Create Project Skills": add `disable-model-invocation: true` to the project copy of `scaffold-services`.
- `claude-code-service/tasks/main.yml` — install `poiesis-purge-check` to `/usr/local/bin` (mode `0755`); add `version: "{{ claude_code_version }}"` to the Claude Code `npm` task.
- `claude-code-service/defaults/main.yml` (new) — `claude_code_version: 2.1.330`.

### Entrypoint & workspace generation

`openclaw/files/entrypoint.sh`:

- After the `POIESIS_HOST_PORT_PREFIX` block (lines 131–136): `POIESIS_IMAGE_NAMESPACE="${POIESIS_IMAGE_NAMESPACE:-$POIESIS_GITHUB_OWNER}"`; exit 1 with a message naming the variable unless it matches `^[a-z0-9]+([._-][a-z0-9]+)*$`; export it.
- `AGENTS.md` heredoc, cycle command (lines 224–228): add `POIESIS_HOST_PORT_PREFIX="${POIESIS_HOST_PORT_PREFIX}"` and `POIESIS_IMAGE_NAMESPACE="${POIESIS_IMAGE_NAMESPACE}"` to the variables placed before `runuser`.
- `AGENTS.md` heredoc, "Scaffolding configuration": state both values and say they are passed to Claude Code in its environment.

### Packer images

- `poiesis-service` rebuilds for both architectures. No new packages. `poiesis-builder` and `poiesis-development` are unaffected.

### Build & release scripts

- `.specs/001-scaffold-contract-fixes/tests/` (new): `run`, `harness.sh`, `README.md`, `fixtures/`, and test files discovered by `run` (the layout hermes uses under its `.specs/*/tests/`).
- `.github/workflows/checks.yml` (new): on push and pull request; `shellcheck` over `infrastructure/ansible/roles/*/files/bin/*`, `infrastructure/ansible/roles/openclaw/files/entrypoint.sh`, `bin/*` and the root `*.sh`; then every `.specs/*/tests/run`. No secrets.
- `README.md`: `POIESIS_IMAGE_NAMESPACE` in the environment table; a Claude Code row in "Pinned Versions" with a short "Bumping Claude Code" paragraph.

### Runtime environment

| Variable | Status | Default | Validation |
|---|---|---|---|
| `POIESIS_IMAGE_NAMESPACE` | new, optional | `POIESIS_GITHUB_OWNER` | Lowercase registry namespace; start-up fails on an invalid value |
| `POIESIS_HOST_PORT_PREFIX` | unchanged | `3` | Unchanged (warn and fall back) |

## Task List

### Slice 1 — Checks that fail today

1. [x] **tests**: Create the harness and synthetic fixtures: `backend-clean`, `backend-two-keys` (`host=0.0.0.0port=8001`), `backend-no-newline`, `backend-coconut`, `frontend-clean`, `frontend-blank-name` (`"name": ""`), `frontend-residue`. Add `purge-check-test` (AC5, AC8, AC4), `settings-test` (AC2: no shipped prompt or skill mentions `/root`, `~/.openclaw` or forbids the environment), `frontmatter-test` (AC9), `run-service-test` (AC13). Record in `tests/README.md` which fail before any fix.

### Slice 2 — The residue check (D3, D4)

2. [x] **script**: Add `files/bin/poiesis-purge-check` as specified above. `purge-check-test` passes.
3. [x] **ansible**: Install it in `claude-code-service/tasks/main.yml`.
4. [x] **skill**: Update the `python-sprint-zero` recipe in `purge-template`: trailing newline, call the script, remove the inline verification.
5. [x] **prompts, skill**: In both prompts and `scaffold-services`, make the port write explicit (`port=<guest>` on its own line) and run `poiesis-purge-check` for every submodule after rename and port, before the first push.

### Slice 3 — Frontend rename (D2)

6. [x] **skill**: Remove the deleting `sed` loop and its verification from the `www-qual-is` recipe.
7. [x] **prompts, skill**: Add the frontend branch to the rename step in both prompts and `scaffold-services`, including the in-context rewrite list and `.purge-allow`.

### Slice 4 — Settings in the environment (D1)

8. [x] **entrypoint**: Pass `POIESIS_HOST_PORT_PREFIX` in the cycle command in the `AGENTS.md` heredoc; reword "Scaffolding configuration".
9. [x] **prompts, skills**: Replace every instruction to read `AGENTS.md` with reading the environment. `settings-test` passes.
10. [x] **tests**: Add `entrypoint-contract-test`: run the entrypoint with stub `openclaw`, `gh`, `git` and `runuser` on `PATH` and a temporary `HOME`; assert the generated `AGENTS.md` command carries both variables (AC1, the static half).

### Slice 5 — Image namespace (D6)

11. [x] **entrypoint**: Default, validate and export `POIESIS_IMAGE_NAMESPACE`; pass it in the cycle command. Extend `entrypoint-contract-test` with a valid, an unset and an invalid value (AC12).
12. [x] **prompts, skill**: Use `${IMAGE_NAMESPACE}` for `docker-tag` and Vagrantfile images.
13. [x] **docs**: Environment table in `README.md`.

### Slice 6 — Loadable skills (D5)

14. [x] **skills**: Remove the flag from `purge-template`, `specify`, `plan`, `scaffold-services`. Add the project-copy rule to `scaffold-project.md`. `frontmatter-test` passes.

### Slice 7 — run-service (D7)

15. [x] **skill**: Rewrite `run-service`. `run-service-test` passes.

### Slice 8 — Pin Claude Code (D8)

16. [x] **ansible**: Add `claude-code-service/defaults/main.yml`; pin the `npm` task.
17. [x] **docs**: "Pinned Versions" row and bump paragraph in `README.md`.

### Slice 9 — Gate and validation

18. [ ] **ci**: Add `.github/workflows/checks.yml`. Its first run is green. *(2026-11-23: added; both steps pass when run by hand in Debian with ShellCheck 0.9.0, as on the runner. Not yet run on GitHub.)*
19. [x] **lint**: `shellcheck` on the new script and `entrypoint.sh`; `ansible-lint` on `claude-code-service` and `openclaw`; `semgrep --config auto`.
20. [ ] **image**: `./build.sh service arm64` and `amd64`. *(2026-11-23: arm64 built and every check below passed; amd64 not built yet.)* In each image, with the entrypoint bypassed: `poiesis-purge-check` is on `PATH`; `claude --version` prints `2.1.330`; `POIESIS_HOST_PORT_PREFIX=4 runuser -u claude -- printenv POIESIS_HOST_PORT_PREFIX` prints `4`; the four `SKILL.md` files lack the flag.
21. [ ] **with credentials**: In the image, ask Claude Code headlessly (`--output-format stream-json`) to run the `purge-template` skill on a copy of `tmp/python-sprint-zero`; confirm the skill loads and the check passes (AC10, AC6).
22. [ ] **end to end**: One scaffold against a throwaway owner with `POIESIS_HOST_PORT_PREFIX=4` and a distinct `POIESIS_IMAGE_NAMESPACE`. Inspect the frontend `package.json`, Packer files and build scripts (AC3), the backend `application.properties` (AC7), and every image name (AC11).
23. [ ] **deployment note**: Record in the pull request that production needs `POIESIS_IMAGE_NAMESPACE=svanosselaer` in the `svo-openclaw` module.

## Spec Coverage

| Criterion | Task(s) |
|---|---|
| AC1 settings in the `claude` process | 8, 10, 20 |
| AC2 no instruction to read `/root` | 1, 9 |
| AC3 frontend name is `P-S` | 6, 7, 22 |
| AC4 frontend check | 1, 2 |
| AC5 two keys on one line detected | 1, 2 |
| AC6 trailing newline after purge | 4, 21 |
| AC7 check passes after port configuration | 5, 22 |
| AC8 clean and coconut fixtures | 1, 2 |
| AC9 flag absent | 1, 14, 20 |
| AC10 skill loads headlessly | 21 |
| AC11 namespace used everywhere | 12, 22 |
| AC12 namespace default and validation | 11 |
| AC13 run-service content | 1, 15 |
| AC14 pinned version | 16, 20 |
| AC15 token-free suite | 1, 2, 9, 14, 15 |
| AC16 CI | 18 |

## Testing Strategy

- **Token-free, in CI:** `.specs/001-scaffold-contract-fixes/tests/run` — fixtures against `poiesis-purge-check`, static assertions on shipped prompts and skills, and the entrypoint run against stubs.
- **Lint:** `shellcheck`, `ansible-lint`, `semgrep`.
- **In the built image, no credentials:** task 20.
- **In the built image, with credentials:** task 21. Repeat it whenever `claude_code_version` changes.
- **End to end:** task 22 against a throwaway GitHub owner and a test blog page with one small concept. Delete the throwaway repositories afterwards by hand.

## Risks & Mitigations

- **Risk:** With the flag gone, Claude Code may load `scaffold-services` unprompted in the service image and create repositories. → **Mitigation:** in the image the only caller is the pipeline, whose prompts ask for exactly that; the copy written into generated projects keeps the flag (task 14).
- **Risk:** The in-context rewrite of `qual.is` references is model work and may be incomplete. → **Mitigation:** `poiesis-purge-check` fails on any remaining reference before the first push (task 5), and 002 repeats it as a stage gate.
- **Risk:** `.purge-allow` becomes a way to silence the check. → **Mitigation:** the script prints the number of allowed paths on every run; the fixture suite includes an allow-listed case so the behaviour is deliberate and visible.
- **Risk:** The templates change shape and the check goes stale (new demo files, renamed blog paths). → **Mitigation:** same coupling scaffold-hardening accepted; the fixture names record which template state they model, and task 21 runs against a real template checkout.
- **Risk:** The pinned Claude Code falls behind. → **Mitigation:** the bump is one variable plus task 21, documented in `README.md`.
- **Risk:** Edits to the two prompts are thrown away when 002 replaces them. → **Mitigation:** the durable changes live in the script, the skills and the entrypoint; prompt edits are kept to the lines the checks assert on.
- **Risk:** A stricter start-up (invalid namespace exits) stops a container that used to start. → **Mitigation:** the variable is new; only a newly set bad value can trigger it, and the message names it.

## Constraint check

No task adds state outside `/root/.openclaw`, a second service, or a dependency on a scaffolded project. Agent behaviour stays in prompts, skills and workspace files; the one new script only reports residue.

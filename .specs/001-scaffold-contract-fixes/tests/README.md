# 001 checks

Verification for [SPEC.md](../SPEC.md). No image, no network, no credentials. The real
`poiesis-purge-check` runs against synthetic fixture trees, the real `entrypoint.sh` runs
against stub commands in a private `HOME`, and the shipped prompts, skills and role are
read as text.

```bash
.specs/001-scaffold-contract-fixes/tests/run
```

`run` finds every `*-test` file in this directory and runs it, collecting failures rather
than stopping at the first. It also runs ShellCheck over the new script and over these
files, and fails rather than skips when ShellCheck is not installed. CI runs it on every
push and pull request (`.github/workflows/checks.yml`).

| File | What it checks |
|---|---|
| `run` | Entry point |
| `harness.sh` | Shared assertions and runners. Sourced, not run |
| `purge-check-test` | `poiesis-purge-check` against the fixtures: AC4, AC5, AC8, the allow-list, usage errors |
| `settings-test` | No shipped prompt or skill points at `/root`, `~/.openclaw` or `AGENTS.md`, or forbids reading the environment (AC2); the three scaffolding documents read both settings from the environment and name images with the namespace (static half of AC11) |
| `frontmatter-test` | `purge-template`, `specify`, `plan` and `scaffold-services` do not set `disable-model-invocation: true` and are installed by the role (AC9); `scaffold-project.md` restores the flag on the project copy of `scaffold-services` |
| `run-service-test` | `run-service` starts and stops through the Vagrantfile, with no `docker build`, `docker run` or `NEXT_PUBLIC` (AC13) |
| `recipe-test` | The purge and rename instructions: no deleting `sed` (D2), no `fgrep -E` (D3), a trailing-newline step (D4), the frontend rename branch, the port on its own line, and the check run before any push |
| `entrypoint-contract-test` | The cycle command in the generated `AGENTS.md` carries both settings and delivers them to the process it starts (AC1, static half); the namespace default, lower-casing and validation (AC12) |
| `role-test` | The role pins Claude Code at `claude_code_version` and installs `poiesis-purge-check` to `/usr/local/bin`, mode `0755` (static half of AC14) |
| `stubs/` | `openclaw`, `gh`, `git`, `node`, `runuser` and `claude`, copied onto `PATH` by the harness |
| `fixtures/` | Synthetic service trees, below |

Sixty cases: 25 in `purge-check-test`, 11 in `entrypoint-contract-test`, 7 in
`recipe-test`, 6 in `settings-test`, 4 each in `frontmatter-test` and `run-service-test`,
3 in `role-test`.

## Fixtures

Each one models a template state that was observed, so a template change that makes one
stale is visible here. `python-sprint-zero` was at `ecc8b26` and `www-qual-is` at `c27186f`
when they were written.

| Fixture | Models |
|---|---|
| `backend-clean` | A backend after purge, rename and port: one key per line, trailing newline, no demo entity |
| `backend-two-keys` | `svo/intent-based-api-api-server` on 2026-04-20: `host=0.0.0.0port=8001` (D4) |
| `backend-no-newline` | The template's `application.properties` after the old purge: last line `host=0.0.0.0`, no newline (D4). The case checks the fixture still has no newline, so an editor or hook that adds one is reported rather than passing silently |
| `backend-coconut` | A purge that missed the demo entity: one file named after it, one test file referring to it |
| `frontend-clean` | A frontend after purge and rename for project `fixture`, service `ui` |
| `frontend-blank-name` | `svo/intent-based-api-ui` on 2026-04-20: `"name": ""`, `source "docker" "-service"`, `svanosselaer/-service`, `svanosselaer/-builder`, `https://www.` (D2) |
| `frontend-residue` | A rename that left `qual.is` and `www-qual-is` references and blog content behind |
| `frontend-allowed` | A clean rename that keeps one reference on purpose, listed in `.purge-allow` |

`.git`, `node_modules` and `.next` cannot sensibly be committed inside a fixture, so
`should_ignore_git_node_modules_and_next_build_output` and `should_ignore_a_submodule_git_file`
create them in the copy at run time.

## Before the fixes

The suite was written first and run against the tree as it stood at `b8d1122`. 4 of the 60
cases passed:

| Case | Why it passed before the fixes |
|---|---|
| `frontmatter-test` `should_carry_frontmatter_naming_the_skill` | Guard: the frontmatter must still be there once the flag is removed |
| `frontmatter-test` `should_install_each_pipeline_skill_into_the_image` | Guard: the role already installed all four |
| `settings-test` `should_find_the_shipped_prompts_and_skills` | Guard: the other cases would pass vacuously if the files moved |
| `settings-test` `should_not_name_a_path_under_root` | Guard: the old text named `~/.openclaw`, not `/root`; `should_not_name_the_openclaw_workspace` is the case that failed |

Everything else failed: 0/25 `purge-check-test` (no script), 0/11 `entrypoint-contract-test`
(the stub `claude` received only `POIESIS_BLOG_URL` and `POIESIS_GITHUB_OWNER`, which is D1),
0/7 `recipe-test`, 0/3 `role-test`, 0/4 `run-service-test`, 2/4 `frontmatter-test`, 2/6
`settings-test`.

To reproduce, export `b8d1122` somewhere, copy this `tests/` directory into the same place in
it, and run `run` there.

## Sensitivity of purge-check-test

`PURGE_CHECK` overrides the script under test:

| Script | Result |
|---|---|
| Exits 0, prints nothing | 6 pass, 19 fail. The six are the clean-tree cases |
| Prints one finding, exits 1 | 0 pass, 25 fail |

## What these checks do not cover

- **The real `runuser`.** The stub runs the command with the environment it was given, which
  is what `runuser -u` does for everything but `HOME`, `SHELL`, `USER` and `LOGNAME`. PLAN.md
  task 20 checks that against the image: `POIESIS_HOST_PORT_PREFIX=4 runuser -u claude --
  printenv POIESIS_HOST_PORT_PREFIX` prints `4`.
- **Whether Claude Code loads the skills** (AC10). That needs credentials: PLAN.md task 21.
- **What a real scaffold produces** (AC3, AC7, AC11 in full). PLAN.md task 22.
- **The CI workflow itself** (AC16) runs only on GitHub. Its two steps were run by hand in a
  Debian container with ShellCheck 0.9.0, the version Ubuntu 24.04 runners ship, and passed.

# Feature: scaffold-hardening

## Overview

Harden Poiesis's scaffolding pipeline against the gaps observed in the first real run (`consented-signal`, 2026-04-05 → 2026-04-17). A working scaffold emerged, but the author had to spend ~12 days fixing template leakage, port collisions, incorrect Vagrantfile structure, wrong frontend backend-wiring strategy, and drifted documentation. This feature closes those gaps inside Poiesis — in the prompts, skills, workspace files, and templates — so the next scaffold is runnable and coherent the day it lands.

This is not a rewrite. It is a set of targeted additions to the existing single-container Poiesis gateway: the scaffolding prompts (`monitor-and-scaffold.md`, `scaffold-project.md`), the service skills shipped via `claude-code-service`, and the generated workspace files. The scaffolding target templates (`svo/python-sprint-zero`, `svo/www-qual-is`) are not owned by this repo and remain out of scope — Poiesis compensates for their quirks at scaffold time.

## Evidence from `consented-signal`

Each acceptance criterion below is tied to a specific commit or artefact from the `consented-signal` retrospective; the evidence column shows what went wrong.

| # | What happened | Evidence |
|---|---|---|
| 1 | Demo entity "Coconut" leaked from `svo/python-sprint-zero` into all 3 services | signal-extractor `1ce1f78` deletes `coconut_use_case.py`, `coconut.py`, `coconut_repository.py`, `coconut_controller.py`, `coconut_data_transfer_object.py`; same pattern in match-engine and referral-gateway |
| 2 | Blog content (`_posts/*`, blog images, `feed.xml`, `sitemap.ts`, blog-specific e2e tests) leaked from `svo/www-qual-is` into the UI | UI `86b08e4` "Removing www.qual.is behaviours" deletes 11,053 lines; `477d8b6` & `ea91b46` "Updating www.qual.is references" |
| 3 | `application.properties` shipped with `host` and `port` concatenated on one line, causing uvicorn DNS errors | 3× identical `fix: add missing newline between host and port in application.properties` |
| 4 | Basic auth wired into the Python template but not wanted at service level | 3× `chore: remove basic auth from <service>` |
| 5 | Prescribed `2` host-port prefix collided locally; ended up using `3` prefix | `1c79947` / `4d775fe` / `f0d87f2` port renumbering; CLAUDE.md & SPEC.md still reference the `2` prefix |
| 6 | Vagrantfile scaffolded as single-VM `config.vm.network "forwarded_port"` style; reality needs Docker provider with one container per service | `1c79947` "add Vagrantfile with Docker provider" — a full rewrite 12 days post-scaffold |
| 7 | Frontend backend-URL wiring iterated four times (NEXT_PUBLIC_ → runtime injection → layout dynamic hack → API proxy routes) | UI `79e6bb6`, `4291d20`, `1883f11`, `74d2cdb`, `26a9080` |
| 8 | UI `docker-tag` kept the template's `www-qual-is` prefix (`svanosselaer/www-consented-signal-qual-is-service`) | Vagrantfile line 56 vs the other three services which use the project-name prefix |
| 9 | Parent `.gitignore` missing `.vagrant/` | `528cd0e` "Ignoring .vagrant directory" |
| 10 | Submodule path wrong at initial add | `50303cc` "Corrected git submodule path" |
| 11 | Parent CLAUDE.md / README / SPEC port numbers never updated when ports changed | Compare parent `CLAUDE.md` (28xxx / 23000) with actual Vagrantfile (38xxx / 33000) |
| 12 | Generated PLAN.md omitted template tear-out as phase-0 work | `.specs/initial/PLAN.md` jumps straight to Phase 1 "Domain models" |

## User Stories

- As **the Poiesis operator**, I want a scaffolded repo that starts with only project-relevant files so that I don't spend the first day deleting template artefacts.
- As **the Poiesis operator**, I want the scaffolded Vagrantfile to reflect the actual Docker-provider multi-container layout so that `vagrant up` works on day one.
- As **the Poiesis operator**, I want host-port assignments to be configurable and non-colliding so that I don't hit port conflicts with other projects on my machine.
- As **the Poiesis operator**, I want the frontend to talk to backends via same-origin API proxy routes from the start so that I am not forced through the CORS / runtime-config / build-time-URL churn.
- As **Claude Code acting as the scaffolder**, I want explicit template-purge steps in the prompt so that demo entities (Coconut), template content (blog posts), and template-only features (basic auth) are gone before the first real commit.
- As **Claude Code acting as the scaffolder**, I want the initial generated docs (parent CLAUDE.md, README, SPEC) to reference the actual ports and image names so the project's truth-of-record is internally consistent.

## Acceptance Criteria

### Template purge

- [ ] Given a fresh backend scaffold from `svo/python-sprint-zero`, when the scaffold completes, then no file under `src/` or `tests/` references `Coconut`, `coconut`, or `COCONUT`.
- [ ] Given a fresh backend scaffold, when the scaffold completes, then `src/*/resources/application.properties` has `host` and `port` on separate lines and uvicorn starts cleanly.
- [ ] Given a fresh backend scaffold where the concept does not call for per-service auth, when the scaffold completes, then no basic-auth wiring remains in `controller/`, `main.py`, `shared/configuration.py`, `application.properties`, or `conftest.py`.
- [ ] Given a fresh frontend scaffold from `svo/www-qual-is`, when the scaffold completes, then `_posts/`, blog-specific `e2e/*.spec.ts` files (`blog`, `about`, `post`, `homepage` in its blog-specific form), `feed.xml`, `sitemap.ts`, `PostService`, `FileSystemPostRepository`, and blog-only public assets under `public/assets/blog/` are removed.
- [ ] Given a fresh frontend scaffold, when `grep -r "qual.is\|www-qual-is"` is run over the repo, then only intentional references remain (e.g. licence/footer attribution if requested).

### Vagrantfile generation

- [ ] Given a project with N backend services and one frontend, when the Vagrantfile is generated, then it contains one `config.vm.define` block per service using the Docker provider and the correct image name from each service's `infrastructure/packer/service.pkr.hcl` `docker-tag`.
- [ ] Given the generated Vagrantfile, when a backend service needs to reach another backend, then its `docker.env` includes `APP_<OTHER_SERVICE>_URL=http://host.docker.internal:<host-port>` for each dependency.
- [ ] Given the generated Vagrantfile, when the frontend needs to reach backends, then its `docker.env` includes `<SERVICE>_URL=http://host.docker.internal:<host-port>` (server-side env vars, not `NEXT_PUBLIC_*`).

### Port strategy

- [ ] Given the scaffolder starts, when it needs to assign host ports, then it reads a `POIESIS_HOST_PORT_PREFIX` env var (single digit, default `3`) and uses it to prefix all assigned host ports.
- [ ] Given two separate scaffolds run on the same host, when the operator sets different `POIESIS_HOST_PORT_PREFIX` values, then no host-port collisions occur between the two projects.
- [ ] Given a scaffold completes, when the operator reads `CLAUDE.md`, `README.md`, `.specs/initial/SPEC.md`, and `Vagrantfile`, then every host-port reference is consistent with the actual generated ports.

### Frontend backend wiring

- [ ] Given a frontend scaffold, when it is produced, then it contains Next.js route handlers at `src/app/api/<service>/[...path]/route.ts` proxying to each backend service.
- [ ] Given the generated route handlers, when a backend is unreachable, then the handler returns HTTP 502 with a structured error body (matches the working pattern in `74d2cdb`).
- [ ] Given the generated frontend, when the codebase is inspected, then no `NEXT_PUBLIC_*_URL` or `window.__RUNTIME_CONFIG__` references exist — backend URLs come from server-only env vars read inside route handlers.

### Docker-tag normalisation

- [ ] Given any service (backend or frontend), when the scaffolder runs, then `infrastructure/packer/service.pkr.hcl` `docker-tag` is `<owner>/<project-name>-<service-name>-service` for both backend and frontend.
- [ ] Given the frontend service, when `service.pkr.hcl` is inspected, then the tag does not contain `www-qual-is`.

### Parent-repo hygiene

- [ ] Given a scaffold completes, when `.gitignore` is inspected in the parent repo, then it contains `.vagrant/` and any other paths specific to the generated local-dev layout.
- [ ] Given `.gitmodules` is inspected after the scaffold, when each submodule URL is checked, then it uses `https://github.com/...` form.
- [ ] Given the scaffold completes, when the author checks, then no commit titled "Corrected git submodule path" is needed — the paths are right the first time.

### Plan template

- [ ] Given a generated `PLAN.md`, when it is read, then it contains a "Phase 0: Template tear-out" with explicit tasks for template purge (Coconut, www.qual.is content, basic auth, application.properties bug).
- [ ] Given a generated `PLAN.md`, when cross-referenced with the generated `SPEC.md`, then every acceptance criterion in the spec maps to at least one task in the plan.

## Surface Impact

### Claude Code configuration (`infrastructure/ansible/roles/claude-code-service/`)

- **`files/prompts/monitor-and-scaffold.md`** — add explicit template-purge steps between the current Step 5 ("Create Service Repositories") and Step 7 ("Configure Ports and Networking"). Update the Vagrantfile example in Step 7 to the Docker-provider multi-container form. Change the port-prefix section to read `POIESIS_HOST_PORT_PREFIX`.
- **`files/prompts/scaffold-project.md`** — mirror the changes to `monitor-and-scaffold.md`.
- **`files/skills/scaffold-services/SKILL.md`** — update the Vagrantfile-update snippet to the Docker-provider form; make the port-prefix configurable; include the template-purge sub-steps per service type; normalise `docker-tag` for frontend.
- **`files/skills/plan/SKILL.md`** — add a "Phase 0: Template tear-out" expectation to the PLAN.md output template.
- **New file `files/skills/purge-template/SKILL.md`** — a single skill that encapsulates the template tear-out for each template type (`python-sprint-zero`, `www-qual-is`). Called from the scaffolding flow.

### OpenClaw configuration (`infrastructure/ansible/roles/openclaw/files/entrypoint.sh`)

- Add `POIESIS_HOST_PORT_PREFIX` to the set of optional env vars surfaced into `AGENTS.md` so Claude Code sees the prefix at scaffold time.
- Document the prefix in the workspace `AGENTS.md` heredoc.

### Workspace-file generation (same `entrypoint.sh`)

- Inject `POIESIS_HOST_PORT_PREFIX` into `AGENTS.md`.
- No change to `IDENTITY.md`, `SOUL.md`, or `USER.md`.

### Packer images

- No base-image change. The existing `poiesis-service` image already ships everything the scaffolder needs (`gh`, `git`, `claude`, `node`). Skill and prompt updates land via `claude-code-service` role file copies — `packer build` rebuilds when those files change.

### Build & release scripts

- No change to `build.sh`, `push.sh`, `create-latest.sh`, `bin/create-image`.

### Runtime environment

- New optional var: `POIESIS_HOST_PORT_PREFIX` (single digit `1`–`9`, default `3`). Validated in `entrypoint.sh` alongside the existing `POIESIS_*` set — warn (not fail) if unset.

## Environment & Configuration

| Variable | Required? | Default | Purpose |
|---|---|---|---|
| `POIESIS_HOST_PORT_PREFIX` | optional | `3` | Single-digit prefix applied to all host-mapped ports in scaffolded Vagrantfiles (e.g. `3` → `38001`, `33000`) |

No other new variables. No changes to auth, Telegram, or Slack configuration.

## Scaffolding Behaviour Impact

- Every scaffolded project now ends the first run with: no template demo entities, no template-branded frontend content, a Docker-provider multi-container Vagrantfile, API-proxy route handlers on the frontend, internally consistent docs.
- The scaffolded `.specs/initial/PLAN.md` starts with a "Phase 0: Template tear-out" section that documents what the scaffolder already did — so the human reviewer sees the tear-out as first-class work rather than implicit.
- Scaffold duration grows slightly (the purge takes time) but the author's post-scaffold fix-up time shrinks by days.

## Operational Impact

- Cron schedule: unchanged.
- Image size: negligible — one new skill file, edits to three prompts/skills.
- Startup time: unchanged.
- Persisted state under `/root/.openclaw`: unchanged.
- Messaging channels: unchanged.

## Constraints

Verified against "What Not to Build" in the platform CLAUDE.md:

- ✅ Not turning Poiesis into a multi-service platform — all changes stay inside the single container.
- ✅ Not hard-coding agent behaviour in entrypoint or roles — tuning is via the generated workspace files and the skills/prompts installed into `/home/claude/.claude/`.
- ✅ Not persisting service state outside `/root/.openclaw`.
- ✅ Not coupling Poiesis to a specific scaffolded project — improvements are scaffold-mechanism-level, not project-level.

## Open Questions

1. **Template ownership.** Some of the observed pain (application.properties newline, basic auth default, Coconut demo, www.qual.is blog content) is a template defect. Fixing the templates upstream (`svo/python-sprint-zero`, `svo/www-qual-is`) would remove the need for Poiesis to compensate. Should we (a) fix templates upstream and simplify Poiesis's purge logic, or (b) leave templates as reference-blogs / demo-apps and purge at scaffold time? Default recommendation: (b), because the templates serve other purposes (demo completeness, new-user onboarding) and the purge is already a clear, testable mechanism.
2. **Auth policy.** Removing basic auth from each scaffolded service assumes the project wants auth at a higher layer (e.g. UI proxy). For projects where per-service auth is desired, the purge should be gated. Proposal: add a heuristic — if the blog-post concept names "public", "open", or "no-auth", purge; otherwise leave and let the user decide. Needs operator input.
3. **Port prefix width.** A single digit (`1`–`9`) caps us at 9 parallel projects on the same host. Consider accepting a two-digit prefix (e.g. `31`, `41`) for operators with more active scaffolds.
4. **Plan phase naming.** `/plan` output currently uses "Phase N" per service. Renaming to "Phase 0: Template tear-out" and bumping subsequent phases changes the existing spec-kit-style convention. Confirm this is acceptable before locking it in.

# Plan: scaffold-hardening

Derived from: `.specs/scaffold-hardening/SPEC.md`

## Implementation Strategy

All changes are scoped to the `claude-code-service` and `openclaw` Ansible roles and the `poiesis-service` Packer image. No new runtime services, no new base packages, no change to the single-container model. The work breaks into seven independently committable slices, ordered so each lands atomically and leaves the image in a runnable state.

Nothing in `svo/python-sprint-zero` or `svo/www-qual-is` is modified — those templates are external, so Poiesis compensates at scaffold time via a new `purge-template` skill that the scaffolding prompts call after each `git submodule add`.

The port-prefix configuration is a single new optional env var (`POIESIS_HOST_PORT_PREFIX`) injected into `AGENTS.md`; the scaffolder reads it from the workspace file, not from `process.env`, preserving the "tune behaviour through workspace files, not entrypoint" rule.

## Surface Changes

### OpenClaw configuration

- No changes to `infrastructure/ansible/roles/openclaw/tasks/main.yml`.
- `infrastructure/ansible/roles/openclaw/files/entrypoint.sh` — extend the `AGENTS.md` heredoc to include the new `POIESIS_HOST_PORT_PREFIX` value and document its semantics. No change to `IDENTITY.md`, `SOUL.md`, or `USER.md` generation. Keep `required_vars` as-is; `POIESIS_HOST_PORT_PREFIX` is optional with a safe default.

### Claude Code configuration

- `infrastructure/ansible/roles/claude-code-service/files/prompts/monitor-and-scaffold.md` — rewrite Steps 6 ("Rename Template References"), 7 ("Configure Ports and Networking"), 9 ("Create Specification"), and 10 ("Create Implementation Plan") so that template purge, Docker-provider Vagrantfile generation, API-proxy route scaffolding, and plan Phase-0 inclusion are explicit.
- `infrastructure/ansible/roles/claude-code-service/files/prompts/scaffold-project.md` — same changes mirrored in the non-cron scaffold prompt (Steps 3, 4, 7, 8).
- `infrastructure/ansible/roles/claude-code-service/files/skills/scaffold-services/SKILL.md` — replace the single-VM `config.vm.network "forwarded_port"` Vagrantfile snippet with a Docker-provider per-service `config.vm.define` block template; make the host-port prefix parameterised off `POIESIS_HOST_PORT_PREFIX`; include a call to the new `/purge-template` skill; normalise `docker-tag` for the frontend template.
- `infrastructure/ansible/roles/claude-code-service/files/skills/plan/SKILL.md` — extend the PLAN.md template to open with a "Phase 0: Template tear-out" section and require every spec acceptance criterion to map to a task.
- New file `infrastructure/ansible/roles/claude-code-service/files/skills/purge-template/SKILL.md` — encapsulates the deterministic purge for each template type (`python-sprint-zero`, `www-qual-is`). Lists the exact files / grep patterns / sed expressions to run.
- `infrastructure/ansible/roles/claude-code-service/tasks/main.yml` — add `purge-template` to both the `Create skills directories` and `Install Claude Code skills` loops.

### Entrypoint & workspace generation

- Extend the `AGENTS.md` heredoc in `entrypoint.sh` to include:
  - A line documenting `POIESIS_HOST_PORT_PREFIX` and its default (`3`).
  - An instruction that when the scaffolder generates a Vagrantfile, it must use this prefix for host ports.
- No changes to startup-check logic beyond adding a warn-only check for `POIESIS_HOST_PORT_PREFIX` format (single digit `1`–`9`).

### Packer images

- `poiesis-service` rebuilds automatically when any file under `infrastructure/ansible/roles/claude-code-service/files/` or `infrastructure/ansible/roles/openclaw/files/entrypoint.sh` changes.
- No new packages or base-image changes.
- `poiesis-development` and `poiesis-builder` — no changes.

### Build & release scripts

- No changes to `build.sh`, `push.sh`, `create-latest.sh`, or any script under `bin/`.

### Runtime environment

| Variable | Status | Default | Validation |
|---|---|---|---|
| `POIESIS_HOST_PORT_PREFIX` | new, optional | `3` | Single digit `1`–`9`; `entrypoint.sh` warns and falls back to default if invalid |

All other `POIESIS_*`, `GITHUB_TOKEN`, `ANTHROPIC_API_KEY`, `TELEGRAM_*`, `SLACK_*` variables — unchanged.

## Task List

Ordered so that each task is independently committable and leaves the image in a runnable state. Commit per task.

### Slice 1 — Introduce the purge-template skill

1. [ ] **skills**: Create `infrastructure/ansible/roles/claude-code-service/files/skills/purge-template/SKILL.md`. Document two purge recipes:
   - `python-sprint-zero`: remove `coconut_*.py` files under `src/**` and `tests/**`; remove `Coconut`-named domain models, repositories, controllers, DTOs, and tests; fix `src/*/resources/application.properties` newline between `host` and `port`; remove basic-auth wiring from `controller/`, `main.py`, `shared/configuration.py`, `application.properties`, `conftest.py`, and related tests.
   - `www-qual-is`: remove `_posts/**`, `public/assets/blog/**`, `public/assets/banner*.png`, `src/app/feed.xml/`, `src/app/sitemap.ts`, `src/app/blog/`, `src/app/posts/`, `src/app/about/`, `src/application/use-cases/GetAllPosts.ts`, `src/application/use-cases/GetAllTopics.ts`, `src/application/use-cases/GetPostBySlug.ts`, `src/application/use-cases/GetPostNavigation.ts`, `src/application/services/PostService.ts`, `src/domain/repositories/IPostRepository.ts`, `src/infrastructure/repositories/FileSystemPostRepository.*`, `src/infrastructure/repositories/InMemoryPostRepository.*`, `src/interfaces/post.ts`, `src/interfaces/author.ts`, `src/interfaces/postNavigation.ts`, `src/lib/markdownToHtml.*`, `src/lib/transformers.*`, `e2e/blog.spec.ts`, `e2e/about.spec.ts`, `e2e/post.spec.ts`, the blog-specific `e2e/homepage.spec.ts` content; grep-and-remove remaining `qual.is` / `www-qual-is` references.
   - Acceptance: covers SPEC criteria "Template purge" items 1–5.
2. [ ] **ansible**: Add `purge-template` to the directories loop and install loop in `infrastructure/ansible/roles/claude-code-service/tasks/main.yml`.
   - Acceptance: skill is present under `/home/claude/.claude/skills/purge-template/` inside the `poiesis-service` image.
3. [ ] **prompts**: Update `files/prompts/monitor-and-scaffold.md` Step 6 and `files/prompts/scaffold-project.md` Step 3 to call `/purge-template <template>` immediately after each `git submodule add`, before "Rename Template References".
   - Acceptance: a scaffold run invokes the purge for every submodule.

### Slice 2 — Port-prefix configuration

4. [ ] **entrypoint**: Update `infrastructure/ansible/roles/openclaw/files/entrypoint.sh` to (a) read `POIESIS_HOST_PORT_PREFIX` with default `3`, (b) validate single digit `1`–`9` (warn and reset to default if not), (c) inject into the `AGENTS.md` heredoc.
   - Acceptance: `AGENTS.md` on a running container contains the prefix value.
5. [ ] **prompts**: Update `monitor-and-scaffold.md` Step 7 and `scaffold-project.md` Step 4 to read the prefix from `AGENTS.md` and use it for all host ports. Explicitly state that parent `CLAUDE.md`, `README.md`, and `.specs/initial/SPEC.md` must reference the same prefix.
   - Acceptance: SPEC criteria "Port strategy" items 1–3 satisfied.
6. [ ] **skill**: Update `files/skills/scaffold-services/SKILL.md` — replace the hard-coded `2` prefix in the port-mapping snippet with `${PORT_PREFIX}` and add a note pointing at `POIESIS_HOST_PORT_PREFIX` in `AGENTS.md`.
   - Acceptance: `/scaffold-services` assigns ports using the configured prefix.

### Slice 3 — Docker-provider multi-container Vagrantfile

7. [ ] **prompts**: Replace the Vagrantfile example in `monitor-and-scaffold.md` Step 7 and `scaffold-project.md` Step 4 with a Docker-provider per-service template. One `config.vm.define '<service>' do |s|` block per service with: `s.vm.provider :docker` → `docker.image = "<owner>/<project-name>-<service>-service:latest"`, `docker.ports = ["${PORT_PREFIX}XXXX:XXXX"]`, `docker.name`, `docker.env` with inter-service URLs and the frontend's backend-URL env vars. Backends that call other backends use `http://host.docker.internal:${PORT_PREFIX}XXXX`.
   - Acceptance: SPEC criteria "Vagrantfile generation" items 1–3 satisfied.
8. [ ] **skill**: Update `files/skills/scaffold-services/SKILL.md` Step 5 (Vagrantfile update) to emit a `config.vm.define` block per service rather than a single `forwarded_port` entry. Include the `APP_<OTHER>_URL` env-var wiring between interdependent services.
   - Acceptance: `/scaffold-services` adds a coherent multi-container block each invocation.

### Slice 4 — Frontend API-proxy route handlers

9. [ ] **prompts**: Add a new step to `monitor-and-scaffold.md` and `scaffold-project.md` (after "Rename Template References") titled "Wire Frontend Backend URLs via API Proxy Routes". Instruct the scaffolder to:
   - For each backend service, create `ui/<ui-repo>/src/app/api/<service>/[...path]/route.ts` exporting `GET`, `POST`, `PUT`, `DELETE`, `PATCH` handlers that read `process.env.<SERVICE>_URL` and forward via `new Request(proxyURL, request)` wrapped in `try/catch`; on `fetch` failure return HTTP 502 with a structured JSON error.
   - Remove any `NEXT_PUBLIC_*` backend URL references.
   - Remove any `window.__RUNTIME_CONFIG__` / runtime-config injection scaffolded by the template.
   - Update the frontend's repository classes (`Http<Service>Repository`) to call same-origin `/api/<service>/...` paths.
   - Ensure the Docker-provider Vagrantfile populates the frontend's `docker.env` with `<SERVICE>_URL=http://host.docker.internal:<host-port>` (server-only, not `NEXT_PUBLIC_`).
   - Acceptance: SPEC criteria "Frontend backend wiring" items 1–3 satisfied.
10. [ ] **skill**: Cross-link from `files/skills/scaffold-services/SKILL.md` (when `--template frontend`) to the new route-handler instructions so ad-hoc `/scaffold-services` runs produce the same shape as the cron flow.
    - Acceptance: `/scaffold-services <name> frontend ...` produces a UI with API proxy routes, not `NEXT_PUBLIC_` bindings.

### Slice 5 — Docker-tag normalisation

11. [ ] **skill**: Update `files/skills/scaffold-services/SKILL.md` Step 7 ("Verify the docker-tag") to an edit step: rewrite `docker-tag` in `infrastructure/packer/service.pkr.hcl` to `<owner>/<project-name>-<service-name>-service` for both backend and frontend. For the frontend, verify no `www-qual-is` substring remains in the tag.
    - Acceptance: SPEC criteria "Docker-tag normalisation" items 1–2 satisfied.
12. [ ] **prompts**: Echo the same requirement in `monitor-and-scaffold.md` Step 8 and `scaffold-project.md` Step 5 ("Update CLAUDE.md Files" — which currently says "Verify each service's docker-tag").
    - Acceptance: both flows produce canonical docker-tags.

### Slice 6 — Parent-repo hygiene

13. [ ] **prompts**: Extend the "Create and Seed the Repository" step in `monitor-and-scaffold.md` (Step 3) to seed a parent `.gitignore` containing at minimum: `.vagrant/`, `.DS_Store`, `node_modules/` (for the frontend submodule parent references), and any temp/cache paths. Same in `scaffold-project.md` (its equivalent step).
    - Acceptance: SPEC criteria "Parent-repo hygiene" item 1 satisfied — no post-scaffold `.vagrant/` commit needed.
14. [ ] **prompts**: In the submodule-add step, explicitly use `https://github.com/...` URLs and call out that the token-rewrite rule in `entrypoint.sh` depends on HTTPS.
    - Acceptance: SPEC criteria "Parent-repo hygiene" items 2–3 satisfied.

### Slice 7 — Plan template and coverage check

15. [ ] **skill**: Update `files/skills/plan/SKILL.md` — extend the PLAN.md output template with a new "Phase 0: Template tear-out" section that must appear before any service-specific phase and must contain tasks for: demo-entity removal, template-content removal, template-bug fixes (application.properties), and template-only feature removal (basic auth) — as applicable per service template.
    - Acceptance: SPEC criteria "Plan template" item 1 satisfied.
16. [ ] **skill**: In the same SKILL.md, add step 4.5: "Every acceptance criterion in `.specs/<spec-name>/SPEC.md` maps to at least one task in the generated PLAN.md. If a criterion is unmapped, the plan is incomplete." Have `/plan` emit a coverage table at the bottom of PLAN.md listing spec criterion → task number.
    - Acceptance: SPEC criteria "Plan template" item 2 satisfied.

### Slice 8 — Validation

17. [ ] **lint**: Run `shellcheck` against the updated `entrypoint.sh`; run `ansible-lint` against the updated `claude-code-service` role; run `semgrep --config auto` against the repo.
    - Acceptance: no new lint findings.
18. [ ] **image**: Rebuild `poiesis-service` for arm64 and amd64 via `./build.sh service arm64` and `./build.sh service amd64`.
    - Acceptance: both builds succeed; image contains `/home/claude/.claude/skills/purge-template/SKILL.md`; `AGENTS.md` heredoc reflects the new `POIESIS_HOST_PORT_PREFIX` docs.
19. [ ] **end-to-end**: Run the service image against a throwaway GitHub target (e.g. a fresh `svo-sandbox` owner) and a test blog URL that proposes a small software concept. Observe a clean scaffold: no Coconut residue, no www.qual.is content, Docker-provider Vagrantfile with `${PORT_PREFIX}` ports, frontend with API proxy routes, internally consistent docs.
    - Acceptance: spec criteria all hold against the generated project; no post-scaffold fix-up commits required for the categories in the spec's Evidence table.

## Spec Coverage

| SPEC criterion | Task(s) |
|---|---|
| Template purge #1 (no Coconut residue) | 1, 2, 3 |
| Template purge #2 (application.properties newline) | 1, 2, 3 |
| Template purge #3 (no basic auth residue) | 1, 2, 3 |
| Template purge #4 (blog content removed) | 1, 2, 3 |
| Template purge #5 (no qual.is references) | 1, 2, 3 |
| Vagrantfile generation #1 (Docker provider per-service) | 7, 8 |
| Vagrantfile generation #2 (backend-to-backend env vars) | 7, 8 |
| Vagrantfile generation #3 (frontend server-only env vars) | 7, 8, 9 |
| Port strategy #1 (POIESIS_HOST_PORT_PREFIX read) | 4 |
| Port strategy #2 (non-colliding when prefix differs) | 4, 5, 6 |
| Port strategy #3 (docs consistent with generated ports) | 5 |
| Frontend wiring #1 (API proxy route handlers) | 9, 10 |
| Frontend wiring #2 (502 on unreachable backend) | 9 |
| Frontend wiring #3 (no NEXT_PUBLIC_, no window.__RUNTIME_CONFIG__) | 9 |
| Docker-tag #1 (canonical form for both types) | 11, 12 |
| Docker-tag #2 (no www-qual-is in frontend tag) | 11, 12 |
| Parent-repo hygiene #1 (.vagrant/ in .gitignore) | 13 |
| Parent-repo hygiene #2 (HTTPS submodule URLs) | 14 |
| Parent-repo hygiene #3 (no submodule-path fix-up commit) | 14 |
| Plan template #1 (Phase 0 present) | 15 |
| Plan template #2 (criteria-to-task mapping) | 16 |

## Testing Strategy

- **Lint gate**: `shellcheck` on `entrypoint.sh`, `ansible-lint` on the `claude-code-service` and `openclaw` roles, `semgrep` over the repo.
- **Local image build**: `./build.sh service arm64` (matches dev host arch), inspected for presence of the new skill file and updated workspace-file generation.
- **Dev-container smoke test**: `vagrant up` with the development image; confirm the new prompts and skill are installed at `/home/claude/.claude/`.
- **End-to-end scaffolding run**: point `POIESIS_BLOG_URL` at a test blog hosting a minimal concept, `POIESIS_GITHUB_OWNER` at a sandbox account, run the container with `POIESIS_HOST_PORT_PREFIX=4` and inspect the generated repo. Check each spec criterion in the Evidence table of `SPEC.md` is now absent as a follow-up commit.
- **Regression**: rerun the `consented-signal` scaffold from scratch in the sandbox and diff the resulting tree against the hand-fixed version — the categorical fixes (Coconut, blog content, basic auth, property newline, Vagrantfile structure, API proxy routes) should no longer be needed.

## Risks & Mitigations

- **Risk**: The template purge in Slice 1 is brittle — if `svo/python-sprint-zero` or `svo/www-qual-is` evolves (adds new demo files or renames blog assets), the purge silently drifts.
  → **Mitigation**: the `purge-template` skill runs `fgrep -rl` grep checks at the end (e.g. `fgrep -r coconut src/ && exit 1`) so an incomplete purge fails loudly. Document the coupling to specific template commits and revisit whenever the templates change.
- **Risk**: Per-project auth sometimes genuinely is wanted at the service level. Blanket basic-auth removal regresses those cases.
  → **Mitigation**: in the scaffolder prompt, gate the basic-auth purge on a heuristic (blog post mentions "public", "open", "no auth") or expose a `POIESIS_SCAFFOLD_STRIP_BASIC_AUTH=true|false` env var (default `true`, matching observed majority). Open question in the spec — confirm before landing Slice 1.
- **Risk**: Port-prefix single-digit cap (`1`–`9`) limits parallel scaffolds on one host.
  → **Mitigation**: if this bites, widen to two digits in a follow-up. Not blocking the first rollout.
- **Risk**: Prescribing API-proxy route handlers locks the frontend into a specific Next.js version / architecture. If `svo/www-qual-is` shifts to Remix or plain React, the prompt text is wrong.
  → **Mitigation**: keep the route-handler instructions tied to the `www-qual-is` template by name, not generic. Revisit if the frontend template changes.
- **Risk**: Extending `AGENTS.md` with new fields changes the prompt every agent session sees. If OpenClaw or Claude Code changes how AGENTS.md is parsed, this becomes fragile.
  → **Mitigation**: keep the additions short and plain-markdown — avoid new structured directives. The existing `POIESIS_*` injection pattern works; this extends it by one line.
- **Risk**: A fresh build-and-push cycle is required to distribute the change to deployed gateways. Operators must pull the new image.
  → **Mitigation**: standard release notes in the PR description; announce in the usual channel.

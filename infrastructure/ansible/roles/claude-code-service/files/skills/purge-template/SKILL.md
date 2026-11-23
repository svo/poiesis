---
name: purge-template
description: Removes demo content, template-only features, and known template defects from a freshly-added submodule cloned from svo/python-sprint-zero or svo/www-qual-is. Call immediately after `git submodule add`, before any renaming or editing. Leaves the submodule ready for project-specific content.
allowed-tools: Bash(find *), Bash(fgrep *), Bash(grep *), Bash(rm *), Bash(sed *), Bash(xargs *), Bash(test *), Bash(cd *), Bash(poiesis-purge-check *), Read, Edit, Write, Grep, Glob
---

# Purge Template

Strips template-only scaffolding from a submodule so that only project-relevant files remain. Run once per submodule, immediately after `git submodule add`.

## Usage

`/purge-template <template> <submodule-path>`

Arguments:
- `$0`: Template name — either `python-sprint-zero` or `www-qual-is`
- `$1`: Submodule path relative to the parent repo (e.g. `services/event-processor`, `ui`)

## Steps

1. **`cd` into the submodule path** (`cd $1`).

2. **Apply the recipe** for the template type (below).

3. **Run the check** at the end of the recipe. `poiesis-purge-check` names each file that still carries template residue and exits non-zero. Fix what it names and run it again; do not commit until it exits 0. For `www-qual-is` the check runs later, after the rename step, because the template name is still present until then.

4. **Stage and commit** the purge inside the submodule:
   ```bash
   git add -A
   git commit -m "chore: purge ${template} demo scaffolding"
   ```

5. **Return to the parent repo** and update the submodule reference:
   ```bash
   cd -
   git add $1
   ```

## Recipe: `python-sprint-zero`

Remove the Coconut demo entity across domain, repository, controller, DTO, and test layers:

```bash
# Demo-entity files (file names vary by case — kill all three)
find src tests -type f \( \
  -iname '*coconut*' \
\) -print -delete

# End application.properties with a newline. The template's last line is
# `host=0.0.0.0` with no newline, so a key appended later would join it.
find src -path '*/resources/application.properties' -print0 \
  | xargs -0 sed -i -e '$a\'

# Remove basic-auth wiring (template-only; services wanting auth add it back later)
for f in $(fgrep -rl -e 'basic_auth' -e 'BasicAuth' -e 'HTTPBasic' src tests 2>/dev/null); do
  case "$f" in
    */conftest.py|*/main.py|*/shared/configuration.py|*/controller/*)
      # Strip basic-auth imports, dependencies, and Depends() injections.
      # If the file is ONLY basic-auth wiring (e.g. a dedicated security module),
      # delete it.
      :
      ;;
  esac
done
# Manually review each file flagged above — remove the auth-specific lines
# (imports, FastAPI dependency parameters, test fixtures). Do NOT remove
# unrelated logic.

# Remove any application.properties `basic_auth.*` keys
find src -path '*/resources/application.properties' -print0 \
  | xargs -0 sed -i -E '/^basic_auth\./d'

# Files that are not named after Coconut still refer to it (conftest.py,
# main.py, test_main.py and others). Edit each one the check names: remove the
# Coconut imports, routes, fixtures and tests. Do NOT remove unrelated logic.

# Check — the recipe is incomplete until this exits 0
poiesis-purge-check python-sprint-zero .
```

Notes:
- Basic auth is removed by default. If the concept (per the blog post) explicitly calls for per-service auth, skip the auth purge for that service and document the choice in the service's `.claude/CLAUDE.md`.
- Do not remove `.github/workflows` — they are disabled at the repo level.

## Recipe: `www-qual-is`

Remove blog content, blog-specific domain code, and template branding:

```bash
# Blog content
rm -rf _posts
rm -rf public/assets/blog
rm -f  public/assets/banner*.png

# Blog routes
rm -rf src/app/feed.xml
rm -rf src/app/blog
rm -rf src/app/posts
rm -rf src/app/about
rm -f  src/app/sitemap.ts

# Blog application layer
rm -f src/application/use-cases/GetAllPosts.ts
rm -f src/application/use-cases/GetAllTopics.ts
rm -f src/application/use-cases/GetPostBySlug.ts
rm -f src/application/use-cases/GetPostNavigation.ts
rm -f src/application/services/PostService.ts

# Blog domain + infrastructure
rm -f src/domain/repositories/IPostRepository.ts
rm -f src/infrastructure/repositories/FileSystemPostRepository.ts
rm -f src/infrastructure/repositories/FileSystemPostRepository.test.ts
rm -f src/infrastructure/repositories/InMemoryPostRepository.ts
rm -f src/infrastructure/repositories/InMemoryPostRepository.test.ts

# Blog interfaces + lib helpers
rm -f src/interfaces/post.ts
rm -f src/interfaces/author.ts
rm -f src/interfaces/postNavigation.ts
rm -f src/lib/markdownToHtml.ts
rm -f src/lib/markdownToHtml.test.ts
rm -f src/lib/transformers.ts
rm -f src/lib/transformers.test.ts

# Blog e2e specs (keep e2e/ directory; replace blog-specific homepage.spec.ts later)
rm -f e2e/blog.spec.ts
rm -f e2e/about.spec.ts
rm -f e2e/post.spec.ts
rm -f e2e/homepage.spec.ts
```

Do **not** delete `www-qual-is` or `qual.is` text here. Deleting the name leaves an empty `package.json` name and image names such as `svanosselaer/-service`. The rename step replaces the name with `<project>-<service>` and rewrites the remaining `qual.is` references in context; `poiesis-purge-check www-qual-is .` runs after it and also confirms the blog paths above are gone.

## Coupling to upstream templates

This skill is tightly coupled to the current shape of `svo/python-sprint-zero` and `svo/www-qual-is`. When either template grows a new demo feature, rename occurs, or restructures, update the corresponding recipe, and the blog paths and property keys in `poiesis-purge-check` (`infrastructure/ansible/roles/claude-code-service/files/bin/` in the Poiesis repository). A silent drift (new demo files slipping through) is contained by `poiesis-purge-check`: it fails the scaffolding run loudly rather than letting a polluted project be pushed.

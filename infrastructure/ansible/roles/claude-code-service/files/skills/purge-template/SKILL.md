---
name: purge-template
description: Removes demo content, template-only features, and known template defects from a freshly-added submodule cloned from svo/python-sprint-zero or svo/www-qual-is. Call immediately after `git submodule add`, before any renaming or editing. Leaves the submodule ready for project-specific content.
disable-model-invocation: true
allowed-tools: Bash(find *), Bash(fgrep *), Bash(grep *), Bash(rm *), Bash(sed *), Bash(test *), Bash(cd *), Read, Edit, Write, Grep, Glob
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

3. **Run the verification grep** at the end of the recipe. If it finds any remaining template residue, fail loudly — do not proceed.

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

# Fix the application.properties newline bug (host and port on one line)
find src -path '*/resources/application.properties' -print0 \
  | xargs -0 sed -i -E 's/^(host=[^[:space:]]+)[[:space:]]*(port=)/\1\n\2/'

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

# Verification — the recipe is incomplete if any of these return a match
if fgrep -r -i 'coconut' src tests 2>/dev/null; then
  echo 'purge-template: coconut residue remains' >&2
  exit 1
fi
if fgrep -rn -E 'host=.+port=' src 2>/dev/null; then
  echo 'purge-template: host=/port= still on one line in application.properties' >&2
  exit 1
fi
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

# Strip remaining qual.is / www-qual-is text references
for f in $(fgrep -rl -e 'qual.is' -e 'www-qual-is' . 2>/dev/null \
           | grep -v '^./.git/' \
           | grep -v '^./node_modules/'); do
  sed -i -E 's/www-qual-is//g; s/qual\.is//g' "$f"
done

# Verification — recipe is incomplete if remaining references are unintentional
residue=$(fgrep -r -e 'qual.is' -e 'www-qual-is' . 2>/dev/null \
          | grep -v '^./.git/' \
          | grep -v '^./node_modules/' || true)
if [ -n "$residue" ]; then
  echo 'purge-template: qual.is / www-qual-is references remain:' >&2
  echo "$residue" >&2
  echo 'If any are intentional (e.g. licence attribution), edit this skill to allow-list them.' >&2
  exit 1
fi

# Verify blog residue is gone
for f in _posts src/app/blog src/app/posts src/app/feed.xml src/app/sitemap.ts \
         src/application/services/PostService.ts; do
  if [ -e "$f" ]; then
    echo "purge-template: $f still present" >&2
    exit 1
  fi
done
```

## Coupling to upstream templates

This skill is tightly coupled to the current shape of `svo/python-sprint-zero` and `svo/www-qual-is`. When either template grows a new demo feature, rename occurs, or restructures, update the corresponding recipe. A silent drift (new demo files slipping through) is contained by the verification greps at the end of each recipe — they fail the scaffolding run loudly rather than producing a polluted project.

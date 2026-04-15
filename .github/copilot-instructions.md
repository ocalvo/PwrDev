# Copilot Instructions — PwrDev

## PR Title and Commit Message Guidelines

This repository uses **release-please** to automate releases. All PR titles
**must** follow the [Conventional Commits](https://www.conventionalcommits.org/)
specification so that release-please can correctly determine version bumps and
generate changelog entries.

### Required Format

```
<type>(<optional scope>): <short description>
```

### Allowed Types

| Type       | Description                                  | Version Bump |
|------------|----------------------------------------------|--------------|
| `feat`     | A new feature                                | minor        |
| `fix`      | A bug fix                                    | patch        |
| `docs`     | Documentation only changes                   | none         |
| `chore`    | Maintenance tasks (deps, CI, tooling)        | none         |
| `refactor` | Code change that neither fixes nor adds      | none         |
| `test`     | Adding or updating tests                     | none         |
| `ci`       | Changes to CI configuration                  | none         |
| `perf`     | Performance improvement                      | patch        |

### Breaking Changes

Append `!` after the type/scope to indicate a breaking change (triggers a major
version bump):

```
feat!: redesign build output paths
fix(build)!: change default platform to ARM64
```

### Examples

```
feat(build): add clang build system support
fix(edit-file): handle spaces in file paths
docs: update README installation instructions
chore(deps): bump actions/checkout to v5
ci: add release-please workflow
```

### Rules

1. **PR titles are squash-commit messages** — they become the single commit on
   `main` and drive release-please automation.
2. **Use imperative mood** — "add feature" not "added feature".
3. **Keep the description concise** — ideally under 72 characters.
4. **Scope is optional** but encouraged for targeted changes (e.g., `build`,
   `deploy`, `edit-file`, `wsl`).
5. **Do not use generic messages** like "update", "fix stuff", or "changes".

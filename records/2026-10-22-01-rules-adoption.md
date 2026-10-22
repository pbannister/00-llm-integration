# Record: Adopt the shared rules

## Outcome

This project now pins the shared rules at `2026-10-22.12`. `rules.lock` holds the
version and a SHA-256 per vendored file, `scripts/rules-check.sh` verifies the
copy, and `tests/04-rules-pin.sh` runs it in the suite.

The adoption was `breaking` for this project. Beyond the contract's safety
precedence and authorization changes, its four local features were rewritten into
the current feature format and its five tasks into the current task format.

## Decisions

- **Three features were renumbered.** `02-dsh-provider-integration.md` collided
  with the shared `02-project-pages.md`. Local features now follow the shared one:
  `03-dsh`, `04-aider`, `05-minerva`. References in tasks and the feature index
  were repointed. A `records/` file that mentions the old names is a record of
  what happened in August; it was not rewritten.
- **The four features were restructured, not rewritten from scratch.** Each kept
  its prose, tables, and code blocks; its normative statements were lifted into
  `## Requirements` with identifiers — `ENDPOINTS-R001`–`R009`,
  `DSH-R001`–`R008`, `AIDER-R001`–`R019`, `MINERVA-R001`–`R007` — and hardware and
  catalog facts stayed in their descriptive sections. No requirement was invented;
  every one existed as a sentence in the original file.
- **`02-project-pages.md` was left untouched.** Its dependency on a skeleton
  feature was a library defect, fixed in the rules rather than worked around here.
- **Deleted `prompts/common/00-overview.md`, `01-requirements.md` and the stale
  `02-universal-rules.md`.** The first two are boilerplate from an older
  generation; the third was superseded by `01-universal-rules.md` and would have
  been a second copy of the rule set. `--prune` cannot remove it on a first
  adoption, because there is no previous lock to compare against.
- **`PHASES.md` is declared** in `prompts/10-project.md`.
- **The glossary states the DELTA term and points at contract section 6.**

## Verification

- `tests/09-prompt-contract.sh`: ok.
- `tests/10-prompt-validator.sh`: 54 rejected, 6 accepted.
- `tests/13-corpus-coverage.sh`: ok.
- `rules-check`: ok (v2026-10-22.12, 39 files, 0 deviations).
- `rules-conform`: nothing to conform.
- `make test`: 8 of 8 pass.

## Behavioral evidence

**Not run, and mostly not runnable.** The six eval cases need files this project
does not carry — `scripts/status.sh`, `scripts/site-state-fetch.sh` — so only
`01-malformed-task-refusal` applies. That limitation is the subject of
`00-project-rules/documents/eval-portability.md` and is not specific to this
project.

## What this adoption cost the library

Three releases, all of them portability defects in shared material that only a
diverged project could reveal:

| Version | Defect |
|---|---|
| `.10` | `how-to-write-tasks.md` and the episode template used a skeleton feature as an example |
| `.11` | `02-project-pages.md` depended on that feature; two eval cases named it. A guard was added |
| `.12` | the adversarial corpus mutated the skeleton's site-build feature and task |

The pattern is one mistake — shared material written against the template's
inventory — and this project is the first adopter that is not a skeleton
descendant, so it found all three at once. `08-shared-references.sh` now guards
the form the guard can see; the corpus case needed a fixture of its own.

## Commits

- Adoption and this record are one commit; see `git log -1` on the adoption.

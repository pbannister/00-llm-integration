# Record: Cache discard — 2026-08-26

## Outcome

Deleted the approved discard-candidate model files from the HuggingFace caches on beast and athena.
Beast: 28 → 13 models (~163 GB freed). Athena: 32 → 15 models (~306 GB freed).
Both routers restarted and now list only the remaining models (`make capture` refreshed, verified 2026-08-26).

## Decisions

- Discard list taken verbatim from `documents/12-model-retention.md` (owner-approved).
- Backups at `/backups/huggingface/` on both hosts are not managed; nothing there was touched.
- Minerva received the travel models before athena's discard ran (copy from athena, not from any deleted cache): Qwen2.5-Coder-3B Q8, Qwen2.5-Coder-1.5B Q8, gemma-4-E2B Q4_K_XL, Qwen3.5-4B Q4_K_M (verified on minerva 2026-08-26).

## Incident (blob cleanup bug) and fix

- The first run of `scripts/cache-discard.sh` on beast deleted the keeper quants (`gpt-oss-120b` UD-Q4_K_XL and `gpt-oss-20b` UD-Q4_K_XL blobs) along with the intended `Q4_K_M` files.
- Root cause: the blob-reference check used `stat -c %i` on snapshot symlinks, which reports the symlink's own inode (no dereference), so keeper blobs looked unreferenced and were removed.
- Fix: use `stat -L -c %i` (dereference) in the reference check; verified on a throwaway fixture.
- Restore: copied the keeper blobs from athena to beast over the LAN with rsync (~65 GB) before running athena's own discard; keepers verified resolving on beast.
- Safeguard for any retry: run `--dry-run`, then verify keeper quants resolve after each host run, before the next host's run.

## Verification

- Both routers' `/v1/models` lists match the remaining caches (13 beast / 15 athena), verified 2026-08-26.
- `make test` passes (config validation against the refreshed captures).
- MTP benchmark (task 01) run on beast; results in `documents/14-service-tuning-recommendations.md`.

## Commits

- (pending) discard execution + docs update.

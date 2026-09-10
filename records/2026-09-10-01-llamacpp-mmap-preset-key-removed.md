# Record: llama.cpp 0.4.0 removed the `mmap` preset key — 2026-09-10

## What happened

After rebuilding llama.cpp to 0.4.0-dev (build 10893, commit 79b0048df) on beast and restarting the services, `llama.service` failed in a systemd restart loop:

```
llama-server: Loaded 6 cached model presets
llama-server: failed to initialize router models: option 'mmap' not recognized in preset '*'
systemd: llama.service: Main process exited, code=exited, status=1/FAILURE
```

Athena (build 10867) still started, because the removal landed between those two builds.

## Root cause

llama.cpp validates preset keys against its own CLI option names (`common/preset.cpp`: the key-to-option map is built from every option's args and env names, and an unknown key throws). The `--mmap`/`--no-mmap` flags were deprecated in favour of `--load-mode` and have now been **removed**, so the `mmap = 1` line in the `[*]` section became an unknown key. The failure is at router preset parsing, before any model loads — hence the restart loop rather than a degraded service.

## Fix (applied, verified)

| Host / service | Config | Change |
| ---- | ---- | ---- |
| beast `llama.service` (:2001, GPU) | `/usr/local/etc/config.ini` | `mmap = 1` → `load-mode = mmap` |
| beast `llama-cpu.service` (:2002) | `/usr/local/etc/config-cpu.ini` | `mmap = 1` → `load-mode = mmap` |
| athena `llama.service` (:2001) | `/usr/local/etc/config.ini` | `mmap = 1` → `load-mode = mmap` |

Each config was dry-run on a scratch port with the new binary before the live restart; baselines saved as `config*.ini.bak-20260910-loadmode` on the respective host.

Verified 2026-09-10:

- beast :2001 — 6 models, aliases `coder14`, `gemma-12b`, `gemma-26b`, `gpt-oss-20b`, `qwen38`, `qwen9`; completion via `coder14` returned OK.
- beast :2002 — `gpt-oss-120b`; completion returned OK (content `OK`, reasoning channel active, 55 completion tokens, `cached_tokens: 60`). Note: gpt-oss emits reasoning tokens first, so a tiny `max_tokens` budget (8) returns empty `content` — not a failure.
- athena :2001 — 16 models, 8 aliased; completion via `coder3` returned OK.
- `load-mode` exists in both builds (10867 and 10893), so the fix is forward- and backward-compatible.

## Lesson

- Preset keys *are* CLI option names: when upstream renames or removes a flag, every preset naming the old key fails hard at router init (systemd restart loop, not a warning).
- Deprecated flags are removed eventually; a config that survives one upgrade can break on the next.
- The rest of the config was unaffected — a full key sweep found `mmap` as the only casualty.

## Safeguards for any retry (and any future llama.cpp rebuild)

1. Run `scripts/preset-keys-check.sh <llama-server> <config.ini>` against the **new** binary and fix every `BAD` key before touching the service.
2. Dry-run the config on a scratch port (`llama-server --models-preset <cfg> --host 127.0.0.1 --port 61xxx`), confirm `listening on ...`, then restart the service.
3. Keep the pre-change config as a dated backup on the host, and re-sync `sources/config/*.applied.ini` in this project.

## Current state / next steps

- All three llama services are active with the 0.4.0-dev builds; no open follow-ups.
- Applied-config archives refreshed from the live hosts (2026-09-10).

# CipherClean
Forensic-grade disk analysis &amp; audit utility for analysts and incident responders (Linux/Unix)

## What it is

CipherClean scans a target directory at high speed, computes SHA-256 for integrity, extracts metadata/aging signals, flags risk, finds duplicates by hash, and lets you export and act on results with an audit trail. It runs as a PyQt6 GUI launched from a single Bash script that bootstraps a clean Python environment with `uv`. (See: “How it works”.)

## Why it exists

- **Evidence handling**: generate verifiable, reproducible artefacts suitable for hand-off.
- **Space recovery**: identify large/old/duplicate files safely before cleanup.
- **Operational safety**: apply exclusion lists, backup-before-delete, and privilege guards.

## Key capabilities

- **Cryptographic verification** — SHA-256 hashing with chunked, threaded workers for speed.  
- **Comprehensive metadata** — path, size, access/modify times, age categories.  
- **Duplicate detection** — bit-accurate grouping by hash; per-file duplicate count shown in the table.  
- **Risk cues** — security-oriented presets and exclusions; multi-step confirm for destructive actions.  
- **Audit artefacts** — CSV export of the results; persistent logs; master & rollback SQLite DBs.  
- **Comfortable UI** — professional dark theme, high-DPI aware, responsive progress updates.

## How it works (pipeline)

1. **Select target** → Choose folder, set size threshold (default 10 MB), apply exclusions.  
2. **Scan** → Walk the tree, collect metadata, enqueue files for hashing with a thread pool.  
3. **Hash & group** → Compute SHA-256 per file in chunks; group on hash to find duplicates.  
4. **Analyse** → Compute age/size buckets, risk cues; update table with duplicate counts and highlights.  
5. **Review & export** → Filter/sort; export CSV; (optional) run controlled cleanup with backups.

## Outputs

- **CSV**: path, size, times, SHA-256, duplicate count, risk fields.  
- **Logs**: console + file logs under `~/.disk_cleanup_logs/`.  
- **Databases**: `~/.disk_cleanup_master.db` (index) and `~/.disk_cleanup_rollback.db` (undo ledger).

## Installation

Requirements: Linux/Unix, Python ≥3.10, `uv` package manager.

```bash
# 1) Install uv once (if needed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2) Run the app
chmod +x CipherClean.sh
./CipherClean.sh

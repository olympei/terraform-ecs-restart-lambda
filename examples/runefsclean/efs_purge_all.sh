#!/usr/bin/env bash
# file: /app/efs_purge_all.sh
# Purpose: Delete EVERYTHING under an EFS directory (no retention/age filter)
# Env vars:
#   EFS_DIR (required)        -> absolute path to the mounted EFS dir (e.g., /mnt/efs/target)
#   DRY_RUN (default: true)   -> set "false" to actually delete
#   EXCLUDE_GLOBS (optional)  -> comma-separated globs to keep (relative to EFS_DIR), e.g. ".trash/*,keep/*"

set -euo pipefail

: "${EFS_DIR:?EFS_DIR is required and must be an absolute path to the EFS mount}"
DRY_RUN="${DRY_RUN:-true}"
EXCLUDE_GLOBS="${EXCLUDE_GLOBS:-}"

# --- Safety checks ---
if [[ ! -d "$EFS_DIR" ]]; then
  echo "❌ EFS_DIR does not exist: $EFS_DIR"; exit 1
fi

REAL_EFS_DIR="$(realpath -m "$EFS_DIR")"
if [[ "$REAL_EFS_DIR" == "/" || "$REAL_EFS_DIR" == "/mnt" || "${#REAL_EFS_DIR}" -lt 8 ]]; then
  echo "❌ Unsafe EFS_DIR: $REAL_EFS_DIR"; exit 2
fi

# Ensure it's an EFS/NFS mount
FSTYPE="$(stat -f -c %T "$REAL_EFS_DIR" || true)"
case "$FSTYPE" in
  nfs*|efs) : ;;
  *) echo "❌ $REAL_EFS_DIR does not look like an EFS/NFS mount (fstype=$FSTYPE)"; exit 3 ;;
esac

echo "📁 Purging everything under: $REAL_EFS_DIR"
[[ -n "$EXCLUDE_GLOBS" ]] && echo "🚫 Excluding: $EXCLUDE_GLOBS"
echo "🧪 Dry-run: $DRY_RUN"

# Build prune clause for excludes
PRUNE=()
if [[ -n "$EXCLUDE_GLOBS" ]]; then
  IFS=',' read -r -a EX_ARR <<< "$EXCLUDE_GLOBS"
  if (( ${#EX_ARR[@]} > 0 )); then
    PRUNE+=( '(' )
    for pat in "${EX_ARR[@]}"; do
      [[ -z "$pat" ]] && continue
      PRUNE+=( -path "$REAL_EFS_DIR/$pat" -o )
    done
    # remove last -o, close group, then prune that subtree
    unset 'PRUNE[${#PRUNE[@]}-1]'
    PRUNE+=( ')' -prune -o )
  fi
fi

FIND_BASE=( find "$REAL_EFS_DIR" -mindepth 1 -xdev )
if [[ "$DRY_RUN" == "true" ]]; then
  # Preview what would be deleted
  "${FIND_BASE[@]}" "${PRUNE[@]}" -print0 \
    | xargs -0 -I{} printf "[DRY-RUN] would delete: %s\n" "{}"
else
  # Delete files and directories (handles dotfiles too)
  "${FIND_BASE[@]}" "${PRUNE[@]}" -print0 \
    | xargs -0 rm -rf --
  echo "✅ Purge complete."
fi

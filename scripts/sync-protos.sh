#!/usr/bin/env bash
#
# Sync the OCP contract protos from ocp-protobuf-api.
#
#   scripts/sync-protos.sh                 # sync at the SHA in ocp.lock
#   scripts/sync-protos.sh <sha|ref>       # re-pin to <sha|ref>, then sync
#   scripts/sync-protos.sh --local [path]  # sync from a local checkout, uncommitted edits included
#
# --local is the contract-authoring loop: edit a .proto in an ocp-protobuf-api checkout,
# sync, regenerate, and build the apps against the result without pushing anything. The
# path defaults to $OCP_UPSTREAM_PATH, then to ../ocp-protobuf-api.
#
# A local sync writes `commit: LOCAL` to ocp.lock. CI and the publish workflow both reject
# that, so proto/ can never reach main or Maven Central without a real upstream commit
# behind it. Re-run with a sha once the contract change is pushed.
#
# Set OCP_UPSTREAM_URL to a local path to sync from a mirror instead of the network. That
# still clones, so it sees committed state only; --local reads the working tree.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_URL="${OCP_UPSTREAM_URL:-git@github.com:code-payments/ocp-protobuf-api.git}"
LOCK="$ROOT/ocp.lock"
DEST="$ROOT/proto"

# The java_package this SDK publishes under. Upstream ships com.codeinc.gen.*, but the
# Android app has always consumed com.codeinc.opencode.gen.* -- the rewrite used to run
# post-fetch in the app's scripts/fetch-protos.sh. It lives here now so the published
# artifact owns its own namespace and consumers need no post-processing.
UPSTREAM_PKG='com.codeinc.gen.'
SDK_PKG='com.codeinc.opencode.gen.'

mode="pinned"
requested=""
local_path=""

case "${1:-}" in
  --local)
    mode="local"
    local_path="${2:-${OCP_UPSTREAM_PATH:-$ROOT/../ocp-protobuf-api}}"
    ;;
  -h|--help)
    sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    requested="${1:-}"
    ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [ "$mode" = "local" ]; then
  SRC="$(cd "$local_path" 2>/dev/null && pwd)" || {
    echo "no such directory: $local_path" >&2
    echo "pass the path to an ocp-protobuf-api checkout, or set OCP_UPSTREAM_PATH." >&2
    exit 1
  }
  echo "==> reading the working tree at $SRC"
  if head="$(git -C "$SRC" rev-parse HEAD 2>/dev/null)"; then
    worktree_state="clean"
    git -C "$SRC" diff --quiet HEAD 2>/dev/null || worktree_state="uncommitted changes"
  else
    head="not a git checkout"
    worktree_state="unversioned"
  fi
  echo "==> local HEAD $head ($worktree_state)"
else
  if [ -z "$requested" ]; then
    [ -f "$LOCK" ] || { echo "no ocp.lock and no ref given; pass a sha to pin" >&2; exit 1; }
    requested="$(awk '/^commit:/ {print $2}' "$LOCK")"
    if [ "$requested" = "LOCAL" ]; then
      echo "ocp.lock records a local sync, so there is no upstream commit to re-sync from." >&2
      echo "Pass a sha to re-pin, or re-run: scripts/sync-protos.sh --local [path]" >&2
      exit 1
    fi
  fi

  SRC="$tmp/upstream"
  echo "==> cloning $UPSTREAM_URL"
  git clone --quiet "$UPSTREAM_URL" "$SRC"
  git -C "$SRC" checkout --quiet "$requested"
  sha="$(git -C "$SRC" rev-parse HEAD)"
  subject="$(git -C "$SRC" log -1 --format='%s')"
  echo "==> pinned at $sha  ($subject)"
fi

[ -d "$SRC/proto" ] || { echo "upstream has no proto/ directory" >&2; exit 1; }

# Contract protos only. buf.yaml / buf.lock / buf.gen.yaml describe how the *contract*
# repo builds Go; they are not part of what this SDK ships.
rm -rf "$DEST"
mkdir -p "$DEST"
( cd "$SRC/proto" && find . -name '*.proto' -type f -print0 ) \
  | ( cd "$SRC/proto" && xargs -0 -I{} sh -c 'mkdir -p "$1/$(dirname "{}")" && cp "{}" "$1/{}"' _ "$DEST" )

# Re-namespace for the Kotlin artifact. Swift is unaffected: java_package does not
# influence swift-protobuf naming.
count=0
while IFS= read -r f; do
  if grep -q "option java_package = \"${UPSTREAM_PKG}" "$f"; then
    sed -i '' "s|option java_package = \"${UPSTREAM_PKG}|option java_package = \"${SDK_PKG}|" "$f"
    count=$((count + 1))
  fi
done < <(find "$DEST" -name '*.proto' -type f)
echo "==> re-namespaced java_package in $count file(s) -> ${SDK_PKG}*"

if grep -rq "\"${UPSTREAM_PKG}" "$DEST"; then
  echo "ERROR: ${UPSTREAM_PKG} still present after rewrite" >&2
  grep -rn "\"${UPSTREAM_PKG}" "$DEST" >&2
  exit 1
fi

if [ "$mode" = "local" ]; then
  cat > "$LOCK" <<LOCK_EOF
# LOCAL SYNC -- proto/ came from a working tree, not a pinned upstream commit.
# Not reproducible: CI and the publish workflow both fail while this says LOCAL.
# Push the contract change, then re-run scripts/sync-protos.sh <sha>.
upstream: $SRC (local working tree)
commit: LOCAL
head: $head ($worktree_state)
LOCK_EOF
else
  cat > "$LOCK" <<LOCK_EOF
# Pinned upstream contract. Regenerate with scripts/sync-protos.sh <sha>.
upstream: code-payments/ocp-protobuf-api
commit: $sha
subject: $subject
LOCK_EOF
fi

echo "==> synced $(find "$DEST" -name '*.proto' | wc -l | tr -d ' ') proto file(s) into proto/"
echo "==> wrote $LOCK"

if [ "$mode" = "local" ]; then
  echo
  echo "    ocp.lock now says LOCAL. This tree is for iterating, not for merging."
fi

#!/usr/bin/env bash
#
# Sync the OCP contract protos from ocp-protobuf-api at a pinned commit.
#
#   scripts/sync-protos.sh                 # sync at the SHA in ocp.lock
#   scripts/sync-protos.sh <sha|ref>       # re-pin to <sha|ref>, then sync
#
# Set OCP_UPSTREAM_URL to a local path to sync from a mirror instead of the network.
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

requested="${1:-}"
if [ -z "$requested" ]; then
  [ -f "$LOCK" ] || { echo "no ocp.lock and no ref given; pass a sha to pin" >&2; exit 1; }
  requested="$(awk '/^commit:/ {print $2}' "$LOCK")"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> cloning $UPSTREAM_URL"
git clone --quiet "$UPSTREAM_URL" "$tmp/upstream"
git -C "$tmp/upstream" checkout --quiet "$requested"
sha="$(git -C "$tmp/upstream" rev-parse HEAD)"
subject="$(git -C "$tmp/upstream" log -1 --format='%s')"
echo "==> pinned at $sha  ($subject)"

[ -d "$tmp/upstream/proto" ] || { echo "upstream has no proto/ directory" >&2; exit 1; }

# Contract protos only. buf.yaml / buf.lock / buf.gen.yaml describe how the *contract*
# repo builds Go; they are not part of what this SDK ships.
rm -rf "$DEST"
mkdir -p "$DEST"
( cd "$tmp/upstream/proto" && find . -name '*.proto' -type f -print0 ) \
  | ( cd "$tmp/upstream/proto" && xargs -0 -I{} sh -c 'mkdir -p "$1/$(dirname "{}")" && cp "{}" "$1/{}"' _ "$DEST" )

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

cat > "$LOCK" <<LOCK_EOF
# Pinned upstream contract. Regenerate with scripts/sync-protos.sh <sha>.
upstream: code-payments/ocp-protobuf-api
commit: $sha
subject: $subject
LOCK_EOF

echo "==> synced $(find "$DEST" -name '*.proto' | wc -l | tr -d ' ') proto file(s) into proto/"
echo "==> wrote $LOCK"

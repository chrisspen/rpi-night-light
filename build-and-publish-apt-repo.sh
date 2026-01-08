#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REMOTE=${REMOTE:-origin}
BRANCH=${BRANCH:-gh-pages}
COMMIT_MSG=${COMMIT_MSG:-"Update apt repo"}
APT_DIR=${APT_DIR:-$ROOT_DIR/apt}

if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository: $ROOT_DIR" >&2
  exit 1
fi

"$ROOT_DIR/build-deb.sh"
"$ROOT_DIR/build-apt-repo.sh"

if [[ ! -d "$APT_DIR" ]]; then
  echo "Missing APT output dir: $APT_DIR" >&2
  exit 1
fi

WORKTREE=$(mktemp -d "${TMPDIR:-/tmp}/rpi-night-light-gh-pages.XXXXXX")
cleanup() {
  git -C "$ROOT_DIR" worktree remove -f "$WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$WORKTREE"
}
trap cleanup EXIT

if git -C "$ROOT_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git -C "$ROOT_DIR" worktree add "$WORKTREE" "$BRANCH"
elif git -C "$ROOT_DIR" ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
  git -C "$ROOT_DIR" worktree add -b "$BRANCH" "$WORKTREE" "$REMOTE/$BRANCH"
else
  git -C "$ROOT_DIR" worktree add --detach "$WORKTREE"
  (
    cd "$WORKTREE"
    git checkout --orphan "$BRANCH"
    git rm -rf . >/dev/null 2>&1 || true
  )
fi

find "$WORKTREE" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$APT_DIR"/. "$WORKTREE"/

git -C "$WORKTREE" add -A
if git -C "$WORKTREE" diff --cached --quiet; then
  echo "No changes to publish."
  exit 0
fi

git -C "$WORKTREE" commit -m "$COMMIT_MSG"
git -C "$WORKTREE" push "$REMOTE" "$BRANCH"

echo "Published APT repo to $REMOTE/$BRANCH"

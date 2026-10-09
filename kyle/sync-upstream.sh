#!/usr/bin/env bash
# Merge an upstream Kaneo release into a sync/<tag> branch cut from origin/kyle.
#
# Usage: kyle/sync-upstream.sh [vX.Y.Z]   (default: newest upstream release)
#
# Exit 0: merged (or kyle already has the release). Exit 1: refused.
# Exit 2: merge conflict, left in progress on sync/<tag> for resolution.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty; commit or discard changes first." >&2
  exit 1
fi

git fetch -q upstream --tags
git fetch -q origin

# Mirror upstream main so the fork's main never diverges. Fails if it has.
git push -q origin refs/remotes/upstream/main:refs/heads/main

# Releases only: vX.Y.Z, not v2.0.0-beta.1, cli-v*, mcp-v*.
tag="${1:-$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)}"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null || {
  echo "No upstream tag $tag." >&2
  exit 1
}

if git merge-base --is-ancestor "$tag" origin/kyle; then
  echo "kyle already contains $tag; nothing to do."
  exit 0
fi

branch="sync/$tag"
git switch -q -c "$branch" origin/kyle
if ! git merge -q --no-ff -m "chore: merge upstream $tag into kyle" "$tag"; then
  echo "Merge conflict on $branch in:" >&2
  git diff --name-only --diff-filter=U >&2
  echo "Resolve, commit, then gate and open the PR (kyle/README.md)." >&2
  exit 2
fi

echo "Merged $tag into $branch. Next: gate, push, PR to kyle (kyle/README.md)."

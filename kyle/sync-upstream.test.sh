#!/usr/bin/env bash
# Tests for sync-upstream.sh against throwaway upstream/origin repos.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync-upstream.sh"
failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

commit() {
  echo "$2" >"$1/$3"
  git -C "$1" add "$3"
  git -C "$1" commit -qm "$4"
}

# upstream: v1.0.0, then v1.1.0 and v1.2.0-beta.1, plus a cli-v tag on main.
# origin: a bare clone whose kyle branch is v1.0.0 plus one local patch.
# work: the clone the script runs in.
setup() {
  root="$(mktemp -d)"
  git init -q -b main "$root/upstream"
  commit "$root/upstream" "base" app.txt "base"
  git -C "$root/upstream" tag v1.0.0
  commit "$root/upstream" "base" upstream.txt "upstream change"
  git -C "$root/upstream" tag v1.1.0
  commit "$root/upstream" "beta" beta.txt "beta change"
  git -C "$root/upstream" tag v1.2.0-beta.1
  git -C "$root/upstream" tag cli-v9.9.9

  git clone -q --bare "$root/upstream" "$root/origin.git"
  git clone -q "$root/origin.git" "$root/work"
  git -C "$root/work" remote add upstream "$root/upstream"
  git -C "$root/work" switch -q -c kyle v1.0.0
  commit "$root/work" "patched" patch.txt "local patch"
  git -C "$root/work" push -q origin kyle
}

run_sync() {
  (cd "$root/work" && "$SCRIPT" "$@") >"$root/out" 2>&1
}

test_merges_latest_release_into_a_sync_branch() {
  setup
  run_sync
  local status=$?
  [ "$status" -eq 0 ] || fail "merge: exit $status, want 0: $(cat "$root/out")"
  git -C "$root/work" rev-parse -q --verify sync/v1.1.0 >/dev/null ||
    fail "merge: branch sync/v1.1.0 missing"
  git -C "$root/work" merge-base --is-ancestor v1.1.0 sync/v1.1.0 ||
    fail "merge: sync branch does not contain v1.1.0"
  git -C "$root/work" merge-base --is-ancestor origin/kyle sync/v1.1.0 ||
    fail "merge: sync branch dropped the local patch"
  git -C "$root/work" merge-base --is-ancestor v1.2.0-beta.1 sync/v1.1.0 &&
    fail "merge: pre-release tag was merged"
}

test_mirrors_upstream_main_to_origin_main() {
  setup
  commit "$root/upstream" "unreleased" next.txt "unreleased upstream change"
  run_sync
  [ "$(git -C "$root/origin.git" rev-parse main)" = "$(git -C "$root/upstream" rev-parse main)" ] ||
    fail "mirror: origin main is not upstream main"
}

test_accepts_an_explicit_tag() {
  setup
  run_sync v1.0.0
  local status=$?
  [ "$status" -eq 0 ] || fail "explicit: exit $status, want 0"
  grep -q "already contains v1.0.0" "$root/out" || fail "explicit: no up-to-date message: $(cat "$root/out")"
}

test_does_nothing_when_kyle_already_has_the_release() {
  setup
  git -C "$root/work" merge -q --no-edit v1.1.0
  git -C "$root/work" push -q origin kyle
  run_sync
  local status=$?
  [ "$status" -eq 0 ] || fail "up-to-date: exit $status, want 0"
  git -C "$root/work" rev-parse -q --verify sync/v1.1.0 >/dev/null &&
    fail "up-to-date: created a sync branch anyway"
}

test_stops_on_conflict_and_names_the_files() {
  setup
  commit "$root/work" "local edit" upstream.txt "conflicting local patch"
  git -C "$root/work" push -q origin kyle
  run_sync
  local status=$?
  [ "$status" -eq 2 ] || fail "conflict: exit $status, want 2"
  grep -q "upstream.txt" "$root/out" || fail "conflict: file not named: $(cat "$root/out")"
}

test_refuses_a_dirty_tree() {
  setup
  echo "wip" >>"$root/work/app.txt"
  run_sync
  local status=$?
  [ "$status" -eq 1 ] || fail "dirty: exit $status, want 1"
  git -C "$root/work" rev-parse -q --verify sync/v1.1.0 >/dev/null &&
    fail "dirty: created a sync branch anyway"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  "$t"
done

if [ "$failures" -eq 0 ]; then
  echo "PASS"
else
  echo "$failures failure(s)"
  exit 1
fi

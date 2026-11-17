#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
export GH_REPO='UmaHarano/ArcZa'
export GH_TOKEN='test-placeholder-not-a-credential'
export ARZ_TEST_LOG="$scratch/commands"

gh() {
  printf 'gh %s\n' "$*" >> "$ARZ_TEST_LOG"
  case "$*" in
    'api repos/UmaHarano/ArcZa --jq .allow_auto_merge') printf '%s\n' "${ARZ_ENABLED:-true}" ;;
    api*branches/main/protection*) printf '%s\n' "${ARZ_PROTECTED:-true}" ;;
    'api --method GET repos/UmaHarano/ArcZa/pulls'*) printf '%s\n' "${ARZ_EXISTING:-}" ;;
    'api --method POST repos/UmaHarano/ArcZa/pulls'*) printf '%s\n' "${ARZ_NUMBER:-17}" ;;
    'pr merge 17 --repo UmaHarano/ArcZa --auto --merge --match-head-commit '*) ;;
    *) echo "Unexpected GitHub command: $*" >&2; return 1 ;;
  esac
}
git() {
  printf 'git %s\n' "$*" >> "$ARZ_TEST_LOG"
  case "$*" in
    'fetch --no-tags origin main'|'fetch --no-tags https://github.com/microsoft/waza.git main') ;;
    'rev-parse FETCH_HEAD') echo upstream ;;
    'rev-parse origin/main') echo base ;;
    'rev-parse HEAD') echo candidate ;;
    'diff --name-only base HEAD -- .github AGENTS.md') printf '%s\n' "${ARZ_PROTECTED_CHANGES:-}" ;;
    'merge-base --is-ancestor upstream base') return "${ARZ_ANCESTOR:-1}" ;;
    'switch --create arcza/upstream-upstream-base base') ;;
    '-c user.name=ArcZa updater -c user.email=41898282+github-actions[bot]@users.noreply.github.com merge --no-ff --no-edit upstream') return "${ARZ_CONFLICT:-0}" ;;
    'push origin HEAD:refs/heads/arcza/upstream-upstream-base') ;;
    *) echo "Unexpected Git command: $*" >&2; return 1 ;;
  esac
}
export -f gh git

run_case() {
  local name="$1" expected="$2"
  shift 2
  : > "$ARZ_TEST_LOG"
  local actual=0
  (export "$@"; bash "$script_dir/arcza-upstream.sh") > "$scratch/output" 2>&1 || actual=$?
  if [ "$actual" -ne "$expected" ]; then
    cat "$scratch/output" >&2
    echo "FAIL: $name (exit $actual, expected $expected)" >&2
    exit 1
  fi
  echo "PASS: $name"
}
no_mutation() {
  if grep -Eq '^git (switch|push|-c)|^gh (pr merge|api --method POST)' "$ARZ_TEST_LOG"; then
    echo 'Unexpected mutation on a blocked path.' >&2
    exit 1
  fi
}

run_case 'missing credential blocks all API calls' 1 GH_TOKEN=
test ! -s "$ARZ_TEST_LOG"
run_case 'wrong repository blocks all API calls' 1 GH_REPO=someone/else
test ! -s "$ARZ_TEST_LOG"
run_case 'disabled auto-merge blocks updates' 1 ARZ_ENABLED=false
no_mutation
run_case 'missing required checks blocks updates' 1 ARZ_PROTECTED=false
no_mutation
run_case 'existing update PR is not duplicated' 0 ARZ_EXISTING=17
no_mutation
run_case 'ambiguous update PRs block updates' 1 $'ARZ_EXISTING=17\n18'
no_mutation
run_case 'already current skips updates' 0 ARZ_ANCESTOR=0
no_mutation
run_case 'merge conflict prevents push and auto-merge' 1 ARZ_CONFLICT=1
if grep -Eq '^git push|^gh (pr merge|api --method POST)' "$ARZ_TEST_LOG"; then exit 1; fi
run_case 'invalid PR response prevents auto-merge' 1 ARZ_NUMBER=invalid
if grep -q '^gh pr merge' "$ARZ_TEST_LOG"; then exit 1; fi
run_case 'automation changes require a draft PR and manual review' 0 ARZ_PROTECTED_CHANGES=.github/workflows/go-ci.yml
grep -q -- '-F draft=true' "$ARZ_TEST_LOG"
if grep -q '^gh pr merge' "$ARZ_TEST_LOG"; then exit 1; fi
run_case 'valid candidate uses a non-forced push and SHA-bound auto-merge' 0 ARZ_NUMBER=17
grep -q -- '-F draft=false' "$ARZ_TEST_LOG"
grep -Fxq 'git push origin HEAD:refs/heads/arcza/upstream-upstream-base' "$ARZ_TEST_LOG"
grep -Fxq 'gh pr merge 17 --repo UmaHarano/ArcZa --auto --merge --match-head-commit candidate' "$ARZ_TEST_LOG"

(
  unset -f git
  git init --bare --initial-branch=main "$scratch/upstream.git" >/dev/null
  git init --bare --initial-branch=main "$scratch/fork.git" >/dev/null
  git init --initial-branch=main "$scratch/seed" >/dev/null
  cd "$scratch/seed"
  git config user.name 'Updater test'
  git config user.email 'test@example.invalid'
  printf 'base\n' > common.txt
  git add common.txt
  git commit -m base >/dev/null
  git remote add upstream "$scratch/upstream.git"
  git remote add origin "$scratch/fork.git"
  git push upstream main >/dev/null 2>&1
  printf 'ArcZa customization\n' > arcza.txt
  git add arcza.txt
  git commit -m customization >/dev/null
  git push origin main >/dev/null 2>&1

  git clone --quiet "$scratch/upstream.git" "$scratch/upstream-work"
  cd "$scratch/upstream-work"
  git config user.name 'Updater test'
  git config user.email 'test@example.invalid'
  printf 'Microsoft update\n' > upstream.txt
  git add upstream.txt
  git commit -m update >/dev/null
  git push origin main >/dev/null 2>&1

  git clone --quiet "$scratch/fork.git" "$scratch/candidate"
  export ARZ_LOCAL_UPSTREAM="$scratch/upstream.git"
  git() {
    if [ "$*" = 'fetch --no-tags https://github.com/microsoft/waza.git main' ]; then
      command git fetch --no-tags "$ARZ_LOCAL_UPSTREAM" main
    else
      command git "$@"
    fi
  }
  export -f git
  cd "$scratch/candidate"
  bash "$script_dir/arcza-upstream.sh" > "$scratch/real-output" 2>&1 || { cat "$scratch/real-output" >&2; exit 1; }
  test "$(git show HEAD:arcza.txt)" = 'ArcZa customization'
  test "$(git show HEAD:upstream.txt)" = 'Microsoft update'
  git merge-base --is-ancestor origin/main HEAD
  grep -Fxq "gh pr merge 17 --repo UmaHarano/ArcZa --auto --merge --match-head-commit $(git rev-parse HEAD)" "$ARZ_TEST_LOG"
  echo 'PASS: actual Git merge preserves fork customization and incorporates upstream content'

  cd "$scratch/seed"
  printf 'fork change\n' > common.txt
  git commit -am fork-change >/dev/null
  git push origin main >/dev/null 2>&1
  cd "$scratch/upstream-work"
  printf 'upstream change\n' > common.txt
  git commit -am upstream-change >/dev/null
  git push origin main >/dev/null 2>&1
  git clone --quiet "$scratch/fork.git" "$scratch/conflict"
  cd "$scratch/conflict"
  before="$(git ls-remote origin)"
  : > "$ARZ_TEST_LOG"
  if bash "$script_dir/arcza-upstream.sh" > "$scratch/real-output" 2>&1; then
    echo 'Expected actual Git merge conflict, but updater succeeded.' >&2
    exit 1
  fi
  test -n "$(git ls-files --unmerged)"
  test "$(git ls-remote origin)" = "$before"
  if grep -Eq '^gh (pr merge|api --method POST)' "$ARZ_TEST_LOG"; then exit 1; fi
  echo 'PASS: actual Git conflict leaves remote refs unchanged and does not create or merge a PR'
)
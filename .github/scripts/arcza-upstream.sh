#!/usr/bin/env bash
set -euo pipefail

if [ "${GH_REPO:-}" != 'UmaHarano/ArcZa' ]; then
  echo 'This updater is restricted to UmaHarano/ArcZa.' >&2
  exit 1
fi
if [ -z "${GH_TOKEN:-}" ]; then
  echo 'Configure the ARCZA_SYNC_TOKEN Actions secret before enabling unattended updates.' >&2
  exit 1
fi

enabled="$(gh api "repos/$GH_REPO" --jq '.allow_auto_merge')"
protected="$(gh api "repos/$GH_REPO/branches/main/protection" --jq '
  .enforce_admins.enabled == true and
  .required_status_checks.strict == true and
  (["build (windows-latest, windows-x64, arcza.exe)", "ubuntu-latest", "windows-latest", "Lint", "completeness"] - .required_status_checks.contexts | length == 0)
')"
if [ "$enabled" != true ] || [ "$protected" != true ]; then
  echo 'Auto-merge and strict required checks must be configured; refusing to proceed.' >&2
  exit 1
fi

existing="$(gh api --method GET "repos/$GH_REPO/pulls" -f state=open -f base=main --jq '
  [.[] | select(.head.repo.full_name == "UmaHarano/ArcZa" and (.head.ref | startswith("arcza/upstream-")))] | .[].number
')"
if [ -n "$existing" ]; then
  if [[ ! "$existing" =~ ^[0-9]+$ ]]; then
    echo 'Multiple update PRs are open; resolve them manually before continuing.' >&2
    exit 1
  fi
  echo "Update PR #$existing is already open; leaving it for required checks or manual intervention."
  exit 0
fi

git fetch --no-tags origin main
git fetch --no-tags https://github.com/microsoft/waza.git main
upstream_sha="$(git rev-parse FETCH_HEAD)"
base_sha="$(git rev-parse origin/main)"
if git merge-base --is-ancestor "$upstream_sha" "$base_sha"; then
  echo 'No new upstream commits.'
  exit 0
fi

branch="arcza/upstream-$upstream_sha-$base_sha"
git switch --create "$branch" "$base_sha"
git -c user.name='ArcZa updater' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
  merge --no-ff --no-edit "$upstream_sha"
protected_changes="$(git diff --name-only "$base_sha" HEAD -- .github AGENTS.md)"
draft=false
if [ -n "$protected_changes" ]; then
  draft=true
fi
git push origin "HEAD:refs/heads/$branch"
number="$(gh api --method POST "repos/$GH_REPO/pulls" -f base=main -f "head=$branch" \
  -F "draft=$draft" \
  -f title='Update ArcZa from Microsoft Waza' \
  -f body='Automated upstream update. The candidate merges Microsoft Waza into the current ArcZa main without resetting customizations. GitHub auto-merge waits for strict required checks. Conflicts, failing or missing checks, required reviews, and unresolved conversations must not be bypassed. Changes to automation or protection settings require manual review.' \
  --jq '.number')"
if [[ ! "$number" =~ ^[0-9]+$ ]]; then
  echo 'No valid PR number returned; refusing to enable auto-merge.' >&2
  exit 1
fi
if [ "$draft" = true ]; then
  echo "Update PR #$number changes automation or agent instructions and requires manual review."
  exit 0
fi
head_sha="$(git rev-parse HEAD)"
gh pr merge "$number" --repo "$GH_REPO" --auto --merge --match-head-commit "$head_sha"
echo "Update PR #$number is configured to merge only after GitHub requirements are satisfied."
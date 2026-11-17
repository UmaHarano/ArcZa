# ArcZa

ArcZa is an independent fork of [Microsoft Waza](https://github.com/microsoft/waza),
maintained at <https://github.com/UmaHarano/ArcZa>.

## License and Compatibility

Keep the upstream MIT license and copyright notice in distributions. Original
third-party notices and dependency licenses also continue to apply. This fork
does not imply endorsement by Microsoft.

The initial fork uses ArcZa repository and executable branding. Internal Go
module paths, configuration names, environment variables, schemas, dashboard
branding, and historical documentation retain Waza names for compatibility.
Upstream installation instructions and `waza update` refer to Microsoft's
distribution, not an ArcZa update channel. Do not use the inherited updater to
update ArcZa; download a new ArcZa build instead.

## Maintenance

The **ArcZa Upstream Updates** GitHub Actions workflow checks Microsoft's `main`
branch daily at 08:23 UTC and can also be run manually. It opens one upstream
pull request when new commits exist and requests GitHub auto-merge. It merges
the fetched upstream commit into the current ArcZa `main` on a new branch in
this fork, preserving customizations without resets or force-pushes. It follows
upstream `main`, not only stable releases. Later upstream commits wait until the
next update after the open PR is handled.

GitHub must enforce strict, current-base required checks on `main`, including
the Windows ArcZa build, `ubuntu-latest`, `windows-latest`, `Lint`, and
`completeness`. The updater refuses to proceed if these requirements or the
repository auto-merge setting are missing. Failures, missing checks, required
reviews, unresolved conversations, and conflicts must not be bypassed. Updates
that change `.github/` or `AGENTS.md` open as drafts for manual review instead.
An existing update PR is left alone, including one needing manual intervention.
Successful auto-merges trigger a fresh Windows build.

### One-Time Credential Setup

The default `GITHUB_TOKEN` cannot start the normal validation workflows when it
creates an update PR. Unattended updates therefore require a dedicated token:

1. In GitHub account settings, create a fine-grained personal access token
	restricted to **UmaHarano/ArcZa**. Grant **Contents**, **Pull requests**, and
	**Workflows** read/write, and **Administration** read-only. Workflows access
	permits pushing candidates that contain upstream workflow changes; those
	candidates still require manual review. Set an expiration and rotate the
	token before it expires.
2. In the repository's **Settings > Secrets and variables > Actions**, add a
	repository secret named `ARCZA_SYNC_TOKEN`. Enter the token directly into
	GitHub, never into chat, source files, or logs.
3. Keep Actions enabled and repository auto-merge enabled. Run **ArcZa Upstream
	Updates** manually once to verify the credential, or wait for the daily run.

The workflow fails closed when the secret is missing, invalid, or expired. It
does not reuse a local Git credential or fall back to `GITHUB_TOKEN` to create
PRs. To pause updates, disable **ArcZa Upstream Updates**. Disable auto-merge
on any already-open PR separately if it should not merge.

The updater's deterministic safeguard and real local-Git regression checks run
in both the update workflow and the Windows build:

```bash
bash .github/scripts/arcza-upstream.test.sh
```

The **ArcZa Build** workflow runs on pushes and pull requests to `main`, or
manually, on Windows x64 only. Download the
`arcza-windows-x64-*` artifact from a successful Actions run. Artifacts expire after 14 days;
they are development builds, not signed installers or qualified releases.
The smoke check executes `--help` with a rejecting runtime guard. It does not
replace upstream tests, lint, compatibility, or browser acceptance checks.

For a local build, install the Go version required by `go.mod` and Node.js
22.18+ or 24+. From the repository root:

```powershell
npm --prefix web ci
npm --prefix web run build
go build -trimpath -o arcza.exe ./cmd/waza
.\arcza.exe --help
```

CLI help still uses the upstream Waza command name. Dashboard builds rewrite the tracked
`web/dist/index.html`; inspect that diff and preserve existing local edits.
Do not commit unrelated generated entrypoint changes.

Upstream changes must pass the enforced checks before merging. Automation
changes, conflicts, and other blocked PRs require manual review or resolution;
never reset the fork to upstream, as that discards ArcZa customizations.
Passing checks do not prove upstream changes are trustworthy or bug-free.
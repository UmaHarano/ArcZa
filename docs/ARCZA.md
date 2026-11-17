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
pull request when new commits exist; it never merges automatically. The pull
request tracks upstream `main`, not only stable releases, and may accumulate
new commits while open. Recheck the final diff and current-head validation.

Enable Actions in the fork and allow GitHub Actions to create pull requests in
**Settings > Actions > General > Workflow permissions**. PRs created using
`GITHUB_TOKEN` may not trigger other workflows. A maintainer can close and reopen
the PR to trigger checks. Merge conflicts require manual resolution.

The **ArcZa Build** workflow runs on pushes and pull requests to `main`, or
manually, on Windows x64, Linux x64, and macOS ARM64. Download the matching
`arcza-*` artifact from a successful Actions run. Artifacts expire after 14 days;
they are development builds, not signed installers or qualified releases.
The smoke check executes `--help` with a rejecting runtime guard. It does not
replace upstream tests, lint, compatibility, or browser acceptance checks.

For a local build, install the Go version required by `go.mod` and Node.js
22.18+ or 24+. From the repository root:

```bash
npm --prefix web ci
npm --prefix web run build
go build -trimpath -o arcza ./cmd/waza
./arcza --help
```

On Windows, use `-o arcza.exe` and run `.\arcza.exe --help`. CLI help still
uses the upstream Waza command name. Dashboard builds rewrite the tracked
`web/dist/index.html`; inspect that diff and preserve existing local edits.
Do not commit unrelated generated entrypoint changes.

Upstream changes must be reviewed and tested before merging. Conflicts require
manual resolution; never reset the fork to upstream, as that discards ArcZa
customizations. Upstream code and workflows are executable code: review changes
before running workflows with elevated permissions or repository secrets.
# Self-assessment

Per-criterion evidence for [`.github/conformance.yml`](../.github/conformance.yml).

| Field | Value |
|---|---|
| Standard | [Repository Quality Standard](https://github.com/trsdn/.github/blob/v1.21.0/docs/repository-quality-standard.md) **v1.21.0** |
| Assessed on | 2026-09-22 |
| State | **Needs work** |
| Results | 80 pass · 2 partial · 2 fail · 23 n/a |

Remediation was tracked in [#32](https://github.com/trsdn/PtionsPlus/issues/32),
which followed the first assessment in
[#29](https://github.com/trsdn/PtionsPlus/issues/29).

Reassessed against v1.21.0 on 2026-09-22, jumping from v1.6.0. Fourteen
criteria are new since v1.6.0 (`B14`-`B16`, `P10`-`P13`, `R07`-`R09`,
`S11`-`S13`, `W09`); this assessment reads every criterion in the current
standard, not a diff. Three of the new ones needed a change, made in the same
pull request as this record: `B14` (a credential-exposure statement was
missing from `AGENTS.md`), `R08` (README did not tell a consumer what to check
or how), and `W09` (the site carried the vendored design language's default
palette with no project-specific override). `I02` and `I03` newly fail, not
because anything regressed, but because the latest published release,
`v1.2.0`, predates the commit that added the product-identity metadata these
criteria ask for; see [Product Identity](#product-identity). `P08` stays at
`pass` for the reason the v1.6.0 reassessment recorded; see
[Badge hosting](#badge-hosting-p08).

## Profiles

Applicable: Baseline, Public, Software, Package And Release, Product Identity,
Published Site, Agent Readiness, Language And Localization, Accessibility, Data
Protection And Privacy.

Not applicable, with rationale:

| Profile | Why it does not apply |
|---|---|
| Deployable (`D01`–`D06`) | Ptions+ is distributed as a signed artifact that a user installs on their own Mac. There is no environment this project operates, no infrastructure to constrain, and no state it is responsible for backing up. The install path is covered by the Package profile and the README. |
| Documentation (`T01`–`T05`) | The primary product is software. `docs/` holds the published site and the accessibility note, both of which are assessed under the Published Site and Accessibility profiles. |
| Archived (`A01`–`A04`) | The repository is actively maintained. |

## Baseline

| ID | Result | Evidence |
|---|---|---|
| B01 | pass | Repository name and description state that Ptions+ maps extra mouse buttons to per-app keyboard shortcuts on macOS. |
| B02 | pass | [`README.md`](../README.md) covers purpose, audience, an explicit **Status** section, requirements, install, and links. |
| B03 | pass | [`LICENSE`](../LICENSE), MIT, recognised by GitHub. |
| B04 | pass | `.gitignore` excludes `build/`, `dist/`, `TestResults/`, and `.release.env`. `.release.env.example` is tracked; no secret is. |
| B05 | pass | `scripts/validate.sh` runs the full gate from a clean checkout and is named in [`AGENTS.md`](../AGENTS.md#validate-a-change). |
| B06 | pass | `main` requires `Build, analyze, and unit tests` and `UI smoke tests`, requires the branch to be current, requires conversation resolution, and blocks force pushes and deletion. Zero open Dependabot and code-scanning alerts. |
| B07 | pass | macOS 13+, Xcode 15+ documented under **Requirements**. No third-party dependencies. |
| B08 | pass | [`CHANGELOG.md`](../CHANGELOG.md), GitHub releases, and linked issues. |
| B09 | pass | Public, `trsdn-standard` topic set alongside the discovery topics, homepage points at the published site, not archived. |
| B10 | pass | [`.github/CODEOWNERS`](../.github/CODEOWNERS) maps the repository to `@trsdn`; README **Status** and **Support** state the maintenance position; `AGENTS.md` states the review expectation. |
| B11 | pass | This record and [`.github/conformance.yml`](../.github/conformance.yml), validated in CI by [`.github/workflows/conformance.yml`](../.github/workflows/conformance.yml). |
| B12 | pass | `trsdn-standard` topic. |
| B13 | pass | `AGENTS.md` carries a documentation-boundaries table naming one home per fact. Commands and architecture moved out of the README into `AGENTS.md`; `CLAUDE.md` and `.github/copilot-instructions.md` are pointers, enforced by `scripts/check-documentation.sh`. |
| B14 | pass | `AGENTS.md` **Secrets and signing** names each of the five release secrets (`MACOS_CERTIFICATE`, `MACOS_CERTIFICATE_PWD`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`) and states what replaces each one and where, added in this reassessment. |
| B15 | na | README **Requirements** and `AGENTS.md` state Ptions+ has no third-party dependencies; nothing is redistributed. |
| B16 | pass | `gh api repos/trsdn/PtionsPlus/branches/main/protection` shows both force pushes and deletion blocked. |

## Public

| ID | Result | Evidence |
|---|---|---|
| P01 | pass | MIT, recognised by GitHub. |
| P02 | pass | `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md` inherited from [`trsdn/.github`](https://github.com/trsdn/.github); Community Standards reports both present. |
| P03 | pass | Private vulnerability reporting enabled; `SECURITY.md` inherited from the org defaults; README **Security** links the advisory path. |
| P04 | pass | Repository-local [`bug.yml`](../.github/ISSUE_TEMPLATE/bug.yml) and [`feature.yml`](../.github/ISSUE_TEMPLATE/feature.yml) forms, `config.yml` with blank issues disabled and contact links, and the inherited pull-request template. |
| P05 | pass | README covers install, configuration, examples, compatibility, versioning, troubleshooting, security, privacy, accessibility, and support status. |
| P06 | pass | Community Standards at 100%. |
| P07 | pass | Description, 14 topics, and a maintained homepage. |
| P08 | pass | Required order — licence, platform, CI, release, conformance — with every badge linking to what it reports. CI uses GitHub's own workflow badge endpoint, the first-party live image the standard names. Conformance is a committed image, regenerated from the record by a repository event. Licence, platform, and release have no first-party image source and are served live by `img.shields.io`, which v1.6.0 records as a `Pass`. The hardcoded `Swift 5.9` badge this criterion exists to prevent was removed in the previous assessment. Reasoning in [Badge hosting](#badge-hosting-p08). |
| P09 | pass | [`.github/stats/repo-card.svg`](../.github/stats/repo-card.svg) and `repo-card-dark.svg`, generated by [`repo-stats.yml`](../.github/workflows/repo-stats.yml) on a weekly schedule, committed, selected with a `<picture>` element, and self-contained — the only `url()` in either file is an internal filter reference. |
| P10 | pass | [`bug.yml`](../.github/ISSUE_TEMPLATE/bug.yml) collects expected behaviour, actual behaviour, numbered reproduction steps, the Ptions+ version, and the macOS version, plus mouse model and vendor-software fields specific to this product's failure modes. |
| P11 | pass | Inherited [`pull_request_template.md`](https://github.com/trsdn/.github/blob/main/.github/pull_request_template.md) covers what the change does, how it was validated, its risk and compatibility impact, and the related issue. |
| P12 | pass | `gh api repos/trsdn/PtionsPlus/vulnerability-alerts` and `automated-security-fixes` both enabled. |
| P13 | pass | CodeQL default setup, `state: active`, read from `gh api repos/trsdn/PtionsPlus/code-scanning/default-setup`. |

## Software

| ID | Result | Evidence |
|---|---|---|
| S01 | pass | `git clone` then `xcodebuild`. No package manager, no external dependencies, so nothing to pin. |
| S02 | pass | 37 unit tests and 3 UI smoke tests covering `EventStateMachine`, `KeyboardStateCoordinator`, `KeyboardLayoutResolver`, `CoreDockClient`, and `MappingStore`, including corrupt, invalid, and unwritable configuration paths. |
| S03 | pass | `swift-format lint --strict` against a committed [`.swift-format`](../.swift-format), plus `xcodebuild analyze`. Both run in the `Lint, format, and documentation` and `Build, analyze, and unit tests` CI jobs. |
| S04 | pass | CI runs on `macos-latest` and, in the `Oldest supported macOS` job, on `macos-14`. GitHub has retired its `macos-13` images, so `macos-14` is the oldest hosted runner available; the macOS 13 floor stays enforced at compile time by the deployment target. |
| S05 | pass | GitHub secret scanning with push protection enabled. |
| S06 | pass | Release configuration is environment-driven through `.release.env`, which is gitignored, with `.release.env.example` committed. Defaults expose nothing private. |
| S07 | pass | Logging policy documented in [`AGENTS.md`](../AGENTS.md#logging): no configuration contents, no captured key codes outside the user-initiated Debug monitor, no home-directory paths, and no per-event logging on the event-tap hot path. |
| S08 | pass | Dependabot covers GitHub Actions weekly; Dependabot security updates enabled; `@trsdn` owns triage through `CODEOWNERS`. |
| S09 | pass | Two required checks protect `main`; both exist and pass. |
| S10 | pass | `AGENTS.md` documents the architecture, the runtime invariant, and the product constraints; the README documents the event flow. |
| S11 | pass | Every workflow (`ci.yml`, `conformance.yml`, `release.yml`, `repo-stats.yml`) declares a `permissions` block, at the top level or on every job, no broader than the job's work. |
| S12 | pass | All 15 `uses:` references in the four workflows are pinned to a commit SHA (third-party actions) or reference a workflow within the account, satisfying the graduated table. |
| S13 | na | No workflow uses `pull_request_target` or `workflow_run`. |

## Package And Release

| ID | Result | Evidence |
|---|---|---|
| R01 | partial | Name (`CFBundleName` `Ptions+`) and version (`CFBundleShortVersionString` `1.2.0`) are present in the latest published artifact and agree with the repository. Licence and repository URL are not: see `I02`/`I03` below, the same finding. `scripts/verify-version.sh` will enforce all of it starting with the next release. |
| R02 | pass | README **Versioning and compatibility** states semantic versioning and what each bump means for the `config.json` schema, including that downgrade is unsupported across a major. |
| R03 | pass | A `v*` tag runs [`release.yml`](../.github/workflows/release.yml), which builds, signs, notarises, staples, and uploads a ZIP, a DMG, and a SHA-256 file. |
| R04 | pass | `scripts/verify-version.sh --tag` rejects a tag that does not match `MARKETING_VERSION`. |
| R05 | pass | `scripts/verify-release-artifacts.sh` rebuilds the ZIP and DMG from the stapled app and verifies them before upload; the release workflow reruns the full CI suite against the tagged commit first. This reassessment additionally downloaded the published `v1.2.0` `Ptions+.dmg` and `Ptions+.zip`, checked the DMG against its published `.sha256`, and ran `codesign --verify --deep --strict`, `xcrun stapler validate`, and `spctl --assess --type execute` against the unpacked app: all passed (`accepted`, `source=Notarized Developer ID`). Neither artifact was launched. |
| R06 | pass | The release workflow gates on `scripts/changelog.sh release-notes` and publishes the `CHANGELOG.md` section of the tagged version as the release body, so a release cannot ship without described changes. |
| R07 | pass | [`release.yml`](../.github/workflows/release.yml) `Verify changelog and build release notes` reads `CHANGELOG.md` at the tagged commit and fails the release when the tag's section is missing or empty; the same extracted text becomes the published release body, so the two cannot disagree. |
| R08 | pass | README **Install** now states the mechanism (Developer ID signature plus Apple notarisation) and gives the two commands a consumer runs to check it, `codesign --verify` and `spctl --assess`, added in this reassessment. Verified directly against the `v1.2.0` artifact under `R05`. |
| R09 | pass | Secret scan: GitHub secret scanning is enabled and `gh api repos/trsdn/PtionsPlus/secret-scanning/alerts?state=open` returns none. Dependency check: `gh api repos/trsdn/PtionsPlus/dependabot/alerts?state=open` returns none, and Dependabot covers the only third-party surface (GitHub Actions); the app itself has no dependencies. |

## Product Identity

**Finding.** `PtionsPlus/Info.plist` gained `TRSRepositoryURL`, `TRSIssuesURL`, and
`TRSLicenseIdentifier` in commit `a5e9a25` (2026-08-31 13:22 CEST). The latest
published release, `v1.2.0`, was tagged at 11:25 CEST the same day — before that
commit — and `a5e9a25` is not an ancestor of the `v1.2.0` tag. This assessment
downloaded the `v1.2.0` `Ptions+.zip`, unpacked it without launching it, and read
`Contents/Info.plist` with `plutil -p`: it carries `CFBundleName`,
`CFBundleShortVersionString` (`1.2.0`), `CFBundleIdentifier`, and
`NSHumanReadableCopyright`, but none of the three `TRS*` keys, and
`Contents/Resources/` carries no bundled licence text. A local `Debug` build from
the current `main` (`scripts/validate.sh --fast`, `xcb -configuration Debug
build`) was checked the same way and does carry all three keys, confirming the
Info.plist template and build settings work; nothing is broken. This is a
released-version gap, not a broken pipeline: `scripts/verify-version.sh --app`
already fails a release whose archived app is missing any of these keys, so the
next tagged release will carry them or fail its own gate. Per
[Product Identity](https://github.com/trsdn/.github/blob/v1.21.0/docs/repository-quality-standard.md#product-identity),
"a value that appears only in source is not evidence that the artifact carries
it," so `I02` and `I03` are recorded against the artifact as published, not the
source. **Remediation is cutting a new release**, which is a maintainer
decision this assessment does not make.

| ID | Result | Evidence |
|---|---|---|
| I01 | pass | `CFBundleShortVersionString` `1.2.0` in the `v1.2.0` artifact, read directly, matching the tag. |
| I02 | fail | No `TRSRepositoryURL` or `TRSIssuesURL`, or any equivalent key, in the `v1.2.0` artifact's `Info.plist`. Present in source since `a5e9a25`, which postdates the tag. See the finding above. |
| I03 | fail | No `TRSLicenseIdentifier` or `NSHumanReadableCopyright`-equivalent licence identifier, and no bundled licence text, in the `v1.2.0` artifact. Present in source since `a5e9a25`, which postdates the tag. See the finding above. |
| I04 | partial | [`AboutView.swift`](../PtionsPlus/Views/AboutView.swift) reads every value from the bundle through [`ProductIdentity.swift`](../PtionsPlus/Utilities/ProductIdentity.swift) rather than hardcoding it, so the About window is correctly wired in source. But `ProductIdentity.swift` reads `TRSRepositoryURL`/`TRSIssuesURL` from the bundle, which the shipped `v1.2.0` binary does not carry, so the About window in the app a user actually downloads today shows no repository or issue-tracker link until the next release. Not run; read from source, per `I04`'s own rule for an interface the assessor does not operate. |
| I05 | pass | `AppIcon.icns` embedded in the `v1.2.0` bundle (confirmed present in `Contents/Resources/`); the same mark is used on the published site and as the favicon. |
| I06 | pass | `scripts/bump-version.sh` owns the version in the project file and every version marker on the site. `scripts/verify-version.sh --app` fails a release whose archived app is missing any identity key, drifts from the source plist, ships without a bundled licence, or — in CI, where `GITHUB_REPOSITORY` is set — disagrees with the repository the workflow is running in. The one value the current artifact does carry, the version, is correctly build-derived; the mechanism for the rest is in place and gates the next release, which is what `I06` asks for. |

## Published Site

Published at <https://trsdn.github.io/PtionsPlus/> from `main` at `/docs`.

| ID | Result | Evidence |
|---|---|---|
| W01 | pass | GitHub Pages builds from `main` at `/docs`; the site source is committed. The publishing arrangement is recorded in `AGENTS.md` under the layout table and in the high-risk section. |
| W02 | pass | Repository homepage points at the site; the site footer links to the repository, licence, security policy, support, issues, and changelog. |
| W03 | pass | The landing view opens with the name, a one-sentence statement of what Ptions+ is, the maintained status, the version, and the download action, all above the fold. |
| W04 | pass | Name and one-sentence statement; status and version; screenshot; download path; the `Y01` disclosure in its own Privacy section; links to repository, licence, security policy, and support; and a `Page last reviewed` date, which `scripts/bump-version.sh` refreshes on every release. |
| W05 | na | Retired 2026-09-17 (standard 1.12.0); see [decision 0013](https://github.com/trsdn/.github/blob/v1.21.0/docs/decisions/0013-sites-are-designed-not-templated.md). |
| W06 | na | Retired 2026-09-17 (standard 1.12.0); see [decision 0013](https://github.com/trsdn/.github/blob/v1.21.0/docs/decisions/0013-sites-are-designed-not-templated.md). |
| W07 | pass | The Google Fonts `preconnect` hints and stylesheet were removed and IBM Plex is self-hosted from `docs/assets/fonts/`. A network review of the rendered page recorded 11 requests, all same-origin, plus the new `assets/site.css`, also same-origin. `scripts/check-documentation.sh` now fails the build if any resource-loading attribute or vendored stylesheet reintroduces a remote host; the guard was confirmed with a negative test. |
| W08 | pass | Build-from-source instructions and the contributor-facing material were removed from the site, which now links to the repository for depth. |
| W09 | pass | Before this reassessment, the site loaded the vendored Instrument Workshop tokens unmodified — `docs/assets/core.tokens.css`'s `--identity` accent, `#29483c`, matched the design system's own default. [`docs/assets/site.css`](../docs/assets/site.css), added in this reassessment and loaded after the vendored files, overrides `--identity`/`--identity-ink` to a project-specific slate blue for light mode and its dark-mode counterpart, both checked at over 8:1 contrast against their background (WCAG requires 4.5:1). Recorded as a deviation in [`docs/assets/VENDORED.md`](../docs/assets/VENDORED.md). |

## Agent Readiness

| ID | Result | Evidence |
|---|---|---|
| G01 | pass | [`AGENTS.md`](../AGENTS.md) in the repository root. |
| G02 | pass | States purpose, layout, and the authoritative build, test, analyse, lint, validation, and release commands. Every command was run successfully while producing this assessment. |
| G03 | pass | `AGENTS.md` **High-risk operations** covers history rewriting, force pushes, tag creation, secret and signing-credential handling, unattended release and deploy scripts, user-data deletion, and destructive shell. |
| G04 | pass | `CLAUDE.md` and [`.github/copilot-instructions.md`](../.github/copilot-instructions.md) point at `AGENTS.md` and restate nothing. `scripts/check-documentation.sh` fails if either stops referencing it or grows past 20 lines. |
| G05 | pass | `scripts/validate.sh`, one command, succeeds from a clean checkout. |
| G06 | pass | `AGENTS.md` **Machine-owned paths** names the generated version fields, the site version markers, the vendored design-language files, the generated badges and stats cards, and the build output. |
| G07 | pass | `Co-authored-by` trailers on agent-authored commits, pull requests required by branch protection, and human review documented in `AGENTS.md`. |
| G08 | pass | [`.github/github-app.yml`](../.github/github-app.yml) points at `AGENTS.md`, names the four most-broken rules, and registers the Validate scripts. |

## Language And Localization

| ID | Result | Evidence |
|---|---|---|
| L01 | pass | README **Language** declares English as the primary user-facing language. |
| L02 | pass | Source review: all interface strings are English. |
| L03 | pass | README **Language** declares English-only with no locale list. |
| L04 | na | No string catalogs exist, because the app is English-only. There is nothing to keep complete. |
| L05 | pass | The app formats no user-facing dates, numbers, or currency. The single `DateFormatter` renders the Debug monitor's diagnostic timestamp and is deliberately pinned to `en_US_POSIX` with a comment explaining why a log timestamp must not shift with the reader's region. |
| L06 | na | No translated strings exist, so there is nothing to trace to a source string. |
| L07 | pass | README, `docs/`, code, comments, identifiers, commits, issues, and release notes are English. |

## Accessibility

| ID | Result | Evidence |
|---|---|---|
| X01 | pass | [`docs/accessibility.md`](accessibility.md) records the verified keyboard path through the menu bar dropdown, the Settings window, the profile editor, the assign menu, and the app picker. Focus indicators are the system ones and are not suppressed. |
| X02 | pass | Every icon-only control now carries an `accessibilityLabel`, and a hint where the outcome is not implied: the menu bar icon, the add-profile button, the assign and change menus, the clear-mapping button, app-picker rows, and the shortcut recorder. Decorative images are `accessibilityHidden`. |
| X03 | pass | System colours and system text styles throughout, so appearance, accent colour, Increase Contrast, and text size are respected. No state is carried by colour alone: the event-tap status, configuration warning, and permission warning each pair colour with a text label and a symbol. |
| X04 | na | Ptions+ ships no command-line interface. The scripts under `scripts/` are maintainer tooling, not a product surface, and already emit plain text without colour or Unicode decoration. |
| X05 | pass | `docs/accessibility.md` states five known limitations, including that recording a custom shortcut requires a physical key press and that VoiceOver is the only screen reader tested. |

## Data Protection And Privacy

| ID | Result | Evidence |
|---|---|---|
| Y01 | pass | README **Privacy** and the site's Privacy section both state the explicit "none" case for collection, storage, and transmission. |
| Y02 | pass | The app makes no outbound requests. The site's destinations were the two Google Fonts hosts; both were removed, and a network review of the rendered page now shows only same-origin requests. A CI check prevents reintroduction. |
| Y03 | pass | No telemetry, analytics, crash reporting, or update check exists in the source. `AGENTS.md` forbids adding any. |
| Y04 | pass | The single storage location, `~/Library/Application Support/Ptions+/config.json`, is documented in the README with the command to delete it. It is plain JSON, so the user can read, copy, and export it. |
| Y05 | na | No third-party service and no AI provider receives user content, because nothing leaves the machine. |
| Y06 | pass | README **Privacy** states that configuration persists until the user deletes it, and that uninstalling the app does not remove it. |

## Badge hosting (`P08`)

This is the one criterion whose result changed at reassessment, and it changed
because the standard was corrected rather than because this repository was.

Under v1.5.1 the rule asked for images "served from the repository or a
first-party source where practical". That is not assessable — it names no
condition a repository can satisfy — so `P08` sat at `partial` with no work that
would clear it. The v1.5.1 assessment also gave a wrong reason for wanting
first-party images: it claimed `img.shields.io` observes every reader. Markdown
rendered on `github.com` loads external images through GitHub's proxy, so the
host sees the proxy, not the reader. That error was carried over from the `W07`
argument for the published site, where it does hold because a browser fetches
those images directly. Badges appear only in the README, so it did not.

[v1.6.0](https://github.com/trsdn/.github/blob/v1.6.0/docs/repository-quality-standard.md#status-badges)
replaced the test with one that turns on how a value changes:

| Value | Moves without a commit? | First-party image? | Result here |
|---|---|---|---|
| Licence | No | No | Live third-party — `Pass` |
| Platform | No | No | Live third-party — `Pass` |
| CI status | Yes | Yes, GitHub's workflow endpoint | First-party live — `Pass`, the preferred form |
| Latest release | Yes | No | Live third-party — `Pass` |
| Conformance | No | Committed, regenerated from the record | `Pass` |

Two readings of the new rule were checked before recording `pass`, because the
distinction is new and the criterion turns on it.

The committing bullet reads "a badge image **may** be committed to the repository
**only when** a repository event regenerates it", and names licence, platform,
and conformance as qualifying. That is a permission gate on committing, not an
obligation to commit: it forbids committing a moving value, it does not require
committing a stable one. The alternative reading — that "everywhere else" excludes
licence and platform, so both must be committed images — makes "may" do the work
of "must" and leaves a live third-party licence badge with no stated result at
all. The v1.6.0 changelog settles it directly: "No recorded result can turn into
a `Fail` from any of this."

So licence and platform stay live. Committing generated images for them would be
permitted and would gain nothing: it trades a value that is correct by
construction for one that is correct only until the next regeneration.

What remains is an availability and trust dependency on `img.shields.io` for
three of the five badges. That is a real dependency and it is worth revisiting if
a first-party source appears for any of those values, but under v1.6.0 it is not
a defect.

## Open gaps

Three, all from [Product Identity](#product-identity), and all with the same
cause and the same remediation:

- `R01` (partial), `I02` (fail), `I03` (fail): the licence identifier and the
  repository/issue URLs are missing from the `v1.2.0` artifact, because the
  source commit that added them postdates that tag.
- `I04` (partial): the About window is correctly wired to read those same
  values, so it inherits the gap in the currently shipped build.

**Remediation is cutting a new release.** `scripts/verify-version.sh --app`
already gates the next one on all four values being present and agreeing with
source, so the fix is publishing, not further code change. That is a
maintainer decision this assessment does not make.

The 23 recorded `na` results each carry a rationale above, and every other
applicable criterion is at `pass`.

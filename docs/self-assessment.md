# Self-assessment

Per-criterion evidence for [`.github/conformance.yml`](../.github/conformance.yml).

| Field | Value |
|---|---|
| Standard | [Repository Quality Standard](https://github.com/trsdn/.github/blob/main/docs/repository-quality-standard.md) **v1.5.1** |
| Assessed on | 2026-08-31 |
| State | **Healthy** |
| Results | 73 pass · 1 partial · 0 fail · 19 n/a |

Remediation was tracked in [#32](https://github.com/trsdn/PtionsPlus/issues/32),
which followed the first assessment in
[#29](https://github.com/trsdn/PtionsPlus/issues/29).

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
| **P08** | **partial** | The badge block is in the required order — licence, platform, CI, release, conformance — and every value is derived from an authoritative source: licence and release from the GitHub API, CI from the workflow status of `main`, conformance from the committed badge rendered by the record. The gap is the image host: the first four are served by `img.shields.io`, which observes readers. The standard asks for first-party images "where practical", and a dynamic CI-status image is not practical to self-host today. The hardcoded `Swift 5.9` badge that this criterion exists to prevent has been removed. |
| P09 | pass | [`.github/stats/repo-card.svg`](../.github/stats/repo-card.svg) and `repo-card-dark.svg`, generated by [`repo-stats.yml`](../.github/workflows/repo-stats.yml) on a weekly schedule, committed, selected with a `<picture>` element, and self-contained — the only `url()` in either file is an internal filter reference. |

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

## Package And Release

| ID | Result | Evidence |
|---|---|---|
| R01 | pass | `Info.plist` and the build settings agree with the repository metadata; verified by `scripts/verify-version.sh`. |
| R02 | pass | README **Versioning and compatibility** states semantic versioning and what each bump means for the `config.json` schema, including that downgrade is unsupported across a major. |
| R03 | pass | A `v*` tag runs [`release.yml`](../.github/workflows/release.yml), which builds, signs, notarises, staples, and uploads a ZIP, a DMG, and a SHA-256 file. |
| R04 | pass | `scripts/verify-version.sh --tag` rejects a tag that does not match `MARKETING_VERSION`. |
| R05 | pass | `scripts/verify-release-artifacts.sh` rebuilds the ZIP and DMG from the stapled app and verifies them before upload; the release workflow reruns the full CI suite against the tagged commit first. |
| R06 | pass | `CHANGELOG.md` and GitHub release notes. |

## Product Identity

| ID | Result | Evidence |
|---|---|---|
| I01 | pass | `CFBundleShortVersionString` `1.2.0` and `CFBundleVersion` `7` in the built bundle, from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. |
| I02 | pass | `TRSRepositoryURL` and `TRSIssuesURL` in `Info.plist`, confirmed present in the built bundle with `plutil -p`. |
| I03 | pass | `NSHumanReadableCopyright` set from the build settings, `TRSLicenseIdentifier` `MIT`, and the full `LICENSE` text bundled at `Contents/Resources/LICENSE`. |
| I04 | pass | About window, reachable from the menu bar dropdown, showing version and build and linking to the repository and the issue tracker. [`AboutView.swift`](../PtionsPlus/Views/AboutView.swift) reads every value from the bundle through [`ProductIdentity.swift`](../PtionsPlus/Utilities/ProductIdentity.swift) rather than hardcoding it. |
| I05 | pass | `AppIcon.icns` embedded in the bundle; the same mark is used on the published site and as the favicon. |
| I06 | pass | `scripts/bump-version.sh` owns the version in the project file and every version marker on the site. `scripts/verify-version.sh` fails when the built bundle is missing any identity key, when a value drifts from the source plist, when the licence is not bundled, or — in CI, where `GITHUB_REPOSITORY` is set — when the embedded repository and issue URLs disagree with the repository the workflow is actually running in. All four failure paths were exercised with negative tests. |

## Published Site

Published at <https://trsdn.github.io/PtionsPlus/> from `main` at `/docs`.

| ID | Result | Evidence |
|---|---|---|
| W01 | pass | GitHub Pages builds from `main` at `/docs`; the site source is committed. The publishing arrangement is recorded in `AGENTS.md` under the layout table and in the high-risk section. |
| W02 | pass | Repository homepage points at the site; the site footer links to the repository, licence, security policy, support, issues, and changelog. |
| W03 | pass | The landing view opens with the name, a one-sentence statement of what Ptions+ is, the maintained status, the version, and the download action, all above the fold. |
| W04 | pass | Name and one-sentence statement; status and version; screenshot; download path; the `Y01` disclosure in its own Privacy section; links to repository, licence, security policy, and support; and a `Page last reviewed` date, which `scripts/bump-version.sh` refreshes on every release. |
| W05 | pass | Instrument Workshop, vendored into [`docs/assets/`](../docs/assets/), replacing roughly 1,050 lines of bespoke CSS. |
| W06 | pass | Version **v1.5.0** recorded in [`docs/assets/VENDORED.md`](../docs/assets/VENDORED.md) and in the header of each vendored file, with the re-vendoring procedure and a "no deviations" statement. |
| W07 | pass | The Google Fonts `preconnect` hints and stylesheet were removed and IBM Plex is self-hosted from `docs/assets/fonts/`. A network review of the rendered page recorded 11 requests, all same-origin. `scripts/check-documentation.sh` now fails the build if any resource-loading attribute or vendored stylesheet reintroduces a remote host; the guard was confirmed with a negative test. |
| W08 | pass | Build-from-source instructions and the contributor-facing material were removed from the site, which now links to the repository for depth. |

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

## Remaining gap

`P08` is the only criterion not at `pass`. Closing it requires either
self-hosting the CI and release status images — which reintroduces the staleness
problem badges exist to avoid — or accepting a first-party badge renderer at the
account level. It is recorded as `partial` rather than argued away.

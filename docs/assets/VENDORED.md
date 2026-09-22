# Vendored assets

Everything in this directory is copied from another repository. It is
machine-owned: do not edit any of it in place. To update, re-vendor from a tag
and record the new version here and in the header of each file.

## Instrument Workshop

| Item | Value |
|---|---|
| Source | [`trsdn/design-system`](https://github.com/trsdn/design-system) |
| Version | **v1.5.0** |
| Vendored on | 2026-08-31 |

| File here | Source path |
|---|---|
| `core.tokens.css` | `tokens/generated/web/core.tokens.css` |
| `instrument-workshop.css` | `src/web/styles/instrument-workshop.css` |
| `instrument-workshop-fonts.css` | `assets/instrument-workshop-fonts.css` |
| `fonts/ibm-plex/*.woff2` | `assets/fonts/ibm-plex/*.woff2` |

Copying rather than depending is deliberate and is expressly permitted by the
[Repository Quality Standard](https://github.com/trsdn/.github/blob/main/docs/repository-quality-standard.md#design-language):
the design system is maintained privately, so a public site cannot resolve it at
build time, and a vendored copy keeps rendering when the source moves.

### Re-vendoring

```bash
VERSION=v1.5.0
for f in tokens/generated/web/core.tokens.css \
         src/web/styles/instrument-workshop.css \
         assets/instrument-workshop-fonts.css; do
  gh api "repos/trsdn/design-system/contents/$f?ref=$VERSION" \
    -H "Accept: application/vnd.github.raw" > "docs/assets/$(basename "$f")"
done
for f in IBMPlexSans-Regular IBMPlexSans-Medium IBMPlexSans-SemiBold \
         IBMPlexMono-Regular IBMPlexMono-SemiBold; do
  gh api "repos/trsdn/design-system/contents/assets/fonts/ibm-plex/$f.woff2?ref=$VERSION" \
    -H "Accept: application/vnd.github.raw" > "docs/assets/fonts/ibm-plex/$f.woff2"
done
```

Then restore the vendoring header at the top of each CSS file and update the
version in this document.

### Recorded deviations

`assets/site.css`, added 2026-09-22 and not vendored, overrides the `--identity`
and `--identity-ink` tokens to a project-specific accent colour, loaded after
these files. It is the only deviation from the design language as published;
everything else here is unmodified.

## IBM Plex

`fonts/ibm-plex/*.woff2` are IBM Plex Sans and IBM Plex Mono, licensed under the
SIL Open Font License 1.1. The licence text is at
[`fonts/ibm-plex/OFL.txt`](fonts/ibm-plex/OFL.txt) and applies to the font files
only, not to Ptions+ itself, which is MIT-licensed.

They are self-hosted rather than loaded from a font CDN. A remote font host
observes every visitor's address and referrer on a page this project controls,
which criterion `W07` forbids and criterion `Y02` would otherwise require this
project to disclose.

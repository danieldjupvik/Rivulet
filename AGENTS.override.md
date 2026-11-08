# Agent guidance for this Rivulet fork

This file belongs in version control in this fork so its guidance survives across machines and checkouts. Keep it out of upstream contribution PRs and do not copy these fork notes into upstream's documentation.

## Read upstream guidance too

Codex loads this file instead of the root AGENTS.md. Before working, also read the current CLAUDE.md, which contains upstream's architecture, build, test, and code-quality instructions. Some local checkouts have an ignored AGENTS.md symlink to CLAUDE.md; a fresh clone may not. Read CLAUDE.md directly and keep fork notes here rather than editing through that symlink. Global Codex instructions still apply. The user's explicit instructions take precedence.

## Starting a task

1. Read CLAUDE.md and inspect Git status, the current branch, remotes, worktrees, and stashes before changing anything.
2. Identify the requested task and whether it targets the fork or upstream. Choose its branch and base accordingly; do not start unrelated work from the audit notes below.
3. For syncs, PR updates, or cleanup, verify current remote branch tips, PR status, and merged history. Local tracking refs and dated notes may be stale. Check for maintainer commits before updating a contribution branch; never overwrite them.

## UIKit and Apple-reference investigations

- Before changing UIKit layout, animation, focus or navigation, read `Docs/UIKIT_FOUNDATIONS.md` and the relevant sections of CLAUDE.md. Consult the maintainer's design/player docs and `rivulet-tvos-uikit` skill when available; report missing resources rather than inventing their guidance. Historical research is evidence to recheck against current code, not a mandate to rewrite the architecture.
- Saved sidebar feasibility research: `Docs/sidebar-detail-navigation-investigation.md`. No implementation was started. It concerns eligible detail/actor browsing pages, not sidebar access over players, alerts or authentication. Preserve the shell's focus-containment guards and one tab/profile authority.
- Detail motion experiment: `feat/detail-motion`; its WIP commit records the remaining season-row, focus/divider and movie-section issues. Home scroll experiment: `fix/scroll-animation-improvements`; read `Docs/Investigations/2026-11-03-scroll-animation/README.md` on that branch before resuming. Neither experiment is finished merely because it builds.
- Local Apple research root: `~/.codex/visualizations/2026/11/04/01a1a76d-da47-7a52-9349-f364741f4174/`. Start with `detail-motion-investigation/report.html`, its `metadata/` and `recording-measurements/` directories; artwork work lives in `episode-scrim-lab/` and `selector-comparison/`. These artifacts are local, not supplied by a fresh clone. Check existence before relying on them.
- Matching Apple/Rivulet movie and show recordings are in `~/Downloads/`, named `apples-tv-movie-details-animation.mov`, `apples-tv-tvshow-details-animation.mov`, `rivulet-movie-details-animation.mov` and `rivulet-tvshow-details-animation.mov`. Screenshots are in `~/Desktop/`. Verify matching artwork, focus state and capture timing before comparing. Recordings do not prove rendered frame rate; physical-device input/focus checks remain necessary.
- The public index at https://github.com/AazainKhan/tvos-26-decompiled contains derived names, signatures, paths and timings, not Apple source or binaries. Our newer investigation used the local tvOS 27.2 build 24K154 (AppleTV18,1), with tvOS 26.6 build 23L773 (AppleTV5,3) as fallback. Downloads are `~/Downloads/AppleTV18,1_27.2_24K154_FullOTA.aea` and `~/Downloads/AppleTV5,3_26.6_23L773_Restore.ipsw`; the newer artifact is an OTA, not an IPSW restore image.
- For further binary research, read the `reverse-engineer-anything` skill, discover the current REA/Hopper tools and use the installed `ipsw` CLI where appropriate. Locate existing extractions before downloading or extracting again. Record image/build, symbol/address and supporting instructions with each finding. The detail report's successful evidence came from ipsw metadata and ARM64 bodies; Hopper/REA had readiness problems, so do not attribute those results to successful decompilation.
- Distinguish observed runtime behavior, recovered compiled behavior and inference. A method name or global animation constant does not establish the timing of a particular route. Implement through public UIKit APIs; do not copy Apple binaries, artwork or decompiled code into the repository. Keep raw firmware, captures and personal library imagery local.
- Artwork research recovered useful fade-compositing behavior and artwork-associated color metadata. It did not recover Apple's color-selection algorithm; dataset experiments did not justify replacing our existing selector. Do not restart color tuning as a prerequisite for motion or sidebar work.
- Separate chats must not switch or edit the same checkout concurrently. Use separate worktrees if working in parallel, with local-only research paths shared read-only. Run heavy Xcode builds serially; stale open workspaces have reverted SwiftPM checkouts during branch switches, so verify pins and refresh the project before diagnosing missing package files as source failures.

## Fork workflow

- Do not commit, push, merge, or publish PRs without the user's explicit authorization for that work. A request to investigate or implement alone is not authorization to publish.
- Integrate changes into fork main through a fork PR by default; do not bypass branch protection. An explicitly requested local commit on main does not authorize a direct push.
- Use concise conventional commit subjects with a lowercase imperative, such as `fix: preserve episode focus`. Do not include Co-Authored-By trailers.
- Keep fork main integration separate from upstream contribution branches. Base upstream contributions on upstream main; never merge fork main into them, which would expose fork configuration and unrelated changes.
- Never link or reference upstream contribution PRs in fork PR metadata or commit messages unless the user explicitly requests it. Such references create unwanted upstream timeline entries.
- Prefer the visible checkout. Preserve unrelated changes and stashes; do not treat old experiments as disposable without checking.
- Validate code changes with builds and relevant tests. Textually clean merges do not prove behavior or signing works. Physical-device verification matters for tvOS focus and remote gestures.

## Preparing upstream contributions

Apply upstream's technical and product-fit review standards before calling a change ready. The November 2026 integrations exposed specific gaps in our reviews; use these checks to reduce avoidable maintainer work, not to promise acceptance without revisions.

- **Check current integration context.** Inspect recent upstream changes and nearby implementations before designing a fix, then recheck the target branch before submission. Account for new callers, relocated shared code, and features such as theme-video backdrops. Do not solve against an old fork snapshot or discard newer upstream behavior to simplify the patch.
- **Reuse the existing owner.** Prefer the current loader, state machine, input predicate, and animation coordinator. Avoid parallel fetch paths, duplicate gesture state, and separate animations for parts of one transition. Keep abstractions proportional to actual callers; fewer lines alone do not establish a simpler design.
- **Review asynchronous ordering explicitly.** Reuse already-fetched data, cancel superseded work before starting more, and fetch independent inputs concurrently where appropriate. Check stale completion after navigation or reconfiguration, failure/fallback paths, and late data arriving after the user takes focus. Initial positioning must not override subsequent user navigation.
- **Review the whole input sequence.** Share eligibility guards between touch swipes and discrete presses where they represent the same action. Check fresh versus continuing gestures, holds/repeats, arrival on a control, and first/last-item boundaries in both directions. In particular, paging from item 1 to item 0 must not let the same gesture escape into the sidebar. Do not substitute an arbitrary delay for gesture ownership without evidence that timing is the intended policy.
- **Exercise lifecycle transitions.** Check reconfiguration during animation, cancellation, presentation/dismissal, and animated versus immediate updates. Preserve related behavior such as backdrop/video suspension and focus restoration, not only the primary visual effect.
- **Keep the review diff focused.** Separate fork identity/configuration and unrelated cleanup from upstream contributions. Inspect the complete diff against the intended upstream base for accidental changes and redundant state. Use the simplify skill for implementation cleanup, then review behavior again; skill completion is not a quality verdict.
- **Test observable regressions.** Prefer cases that fail before the fix and cover the ordering or boundary that caused the bug. Avoid tests that merely repeat implementation constants. Use controlled async completions or bounded condition waits where possible; isolate locale/timezone and app-identity assumptions. Run the relevant checks and disclose flaky failures even if an isolated rerun passes.
- **Report evidence, not certainty.** State what builds/tests and physical-device checks actually covered, plus remaining gaps. For focus work, distinguish simulator results from remote testing. Do not call code "perfect" or "production-ready" solely because tests, skills, or automated reviews passed. Maintainer edits can be bug fixes, integration requirements, or preferences; distinguish them using the actual diff and carry forward only supported lessons.

## Features the fork intentionally retains

- Keep Dolby Vision Profile 7 FEL composition, Height Speakers / TrueHD Atmos and DTS:X height rendering, and Dolby Vision still reshaping.
- Upstream commit 60bc2b23c82ecf05611a4ea0d63ab42cca3aaa7f removes those features. Do not silently accept that removal during a sync. Prefer normal upstream ancestry with a separate fork restoration commit over cherry-picking every other upstream commit.
- Preserve all four AetherEngine traits: DualLayerDolbyVision, DolbyVisionStillReshaping, TrueHDObjectAudio, DTSXObjectAudio. Retention also requires playback configuration, settings, localization, diagnostics, tests, notices, and resolved dependencies; traits alone are insufficient.
- Keep fork bundle IDs, signing, and app groups. Use the fork-owned iCloud.com.danieldjupvik.rivulet.lab.sync container in both app entitlements and AccountVault. Incoming iCloud settings must match the fork's provisioning, not upstream's container.

## Branch roles (snapshot: 2026-11-06)

Former upstream contribution branches: episode-selection-fix, hero-navigation-improvements, sidebar-improvements. The maintainer integrated all three through new commits and closed their PRs on November 6. Their former merge conflicts no longer need resolution. Verify integration before cleaning up these branches; do not reopen or update the closed PRs automatically.

Existing fork PR branches: feat/episode-poster-effects, fix/episode-detail-navigation, fix/metadata-badge-styling.

Parked experiments: feat/detail-motion and fix/scroll-animation-improvements. Do not resume or merge these without a request. The detail-motion WIP commit records unresolved season-row, focus/divider, and movie-animation issues.

For new branches, prefer contrib/ for upstream contributions, fork/ for fork-specific work, experiment/ for parked investigations, and sync/ for upstream integration. Do not rename existing published branches solely to enforce this convention.

## Audit context (2026-11-06; recheck before acting)

The sync branch sync/upstream-2026-11-06 was created from fork main 96fac940. Commit 807d27d5 merges upstream dd6e1c46 with fork-owned iCloud configuration; be8b50c7 restores Dolby features separately. These commits were local and not merged into fork main when these notes were written. Recheck remote and branch state before acting.

- Upstream adopted gesture-based hero arrival protection for both swipes and button presses. The temporary delay experiment was discarded at the user's request; use the integrated upstream implementation.
- Integrated episode selection includes the maintainer's redundant/superseded-load fixes, concurrent target fetching, and protection against late rail repositioning. Keep these alongside the relocated EpisodePicker helpers.
- AetherEngine 7.57.0 retains the four traits; the restoration pins LibTrueHD 3.2.0. The combined app builds and all 11 targeted Dolby/settings tests pass. The broader suite has known Emby app-name/timezone test failures left unchanged by request, plus a theme-video timing failure that passed an isolated rerun. Physical Dolby playback and cross-device iCloud sync still need validation.

Build and test the combined result before proposing a merge. Leave the parked experiments alone. These notes are context, not standing authorization to commit, push, merge, or publish.

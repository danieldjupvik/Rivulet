# Agent guidance for this Rivulet fork

This file belongs in version control in this fork so its guidance survives across machines and checkouts. Keep it out of upstream contribution PRs and do not copy these fork notes into upstream's documentation.

## Read upstream guidance too

Codex loads this file instead of the root AGENTS.md. Before working, also read the current CLAUDE.md, which contains upstream's architecture, build, test, and code-quality instructions. Some local checkouts have an ignored AGENTS.md symlink to CLAUDE.md; a fresh clone may not. Read CLAUDE.md directly and keep fork notes here rather than editing through that symlink. Global Codex instructions still apply. The user's explicit instructions take precedence.

## Starting a task

1. Read CLAUDE.md and inspect Git status, the current branch, remotes, worktrees, and stashes before changing anything.
2. Identify the requested task and whether it targets the fork or upstream. Choose its branch and base accordingly; do not start unrelated work from the audit notes below.
3. For syncs, PR updates, or cleanup, verify current remote branch tips, PR status, and merged history. Local tracking refs and dated notes may be stale. Check for maintainer commits before updating a contribution branch; never overwrite them.

## Fork workflow

- Do not commit, push, merge, or publish PRs without the user's explicit authorization for that work. A request to investigate or implement alone is not authorization to publish.
- Integrate changes into fork main through a fork PR by default; do not bypass branch protection. An explicitly requested local commit on main does not authorize a direct push.
- Use concise conventional commit subjects with a lowercase imperative, such as `fix: preserve episode focus`. Do not include Co-Authored-By trailers.
- Keep fork main integration separate from upstream contribution branches. Base upstream contributions on upstream main; never merge fork main into them, which would expose fork configuration and unrelated changes.
- Never link or reference upstream contribution PRs in fork PR metadata or commit messages unless the user explicitly requests it. Such references create unwanted upstream timeline entries.
- Prefer the visible checkout. Preserve unrelated changes and stashes; do not treat old experiments as disposable without checking.
- Validate code changes with builds and relevant tests. Textually clean merges do not prove behavior or signing works. Physical-device verification matters for tvOS focus and remote gestures.

## Features the fork intentionally retains

- Keep Dolby Vision Profile 7 FEL composition, Height Speakers / TrueHD Atmos and DTS:X height rendering, and Dolby Vision still reshaping.
- Upstream commit 60bc2b23c82ecf05611a4ea0d63ab42cca3aaa7f removes those features. Do not silently accept that removal during a sync. Prefer normal upstream ancestry with a separate fork restoration commit over cherry-picking every other upstream commit.
- Preserve all four AetherEngine traits: DualLayerDolbyVision, DolbyVisionStillReshaping, TrueHDObjectAudio, DTSXObjectAudio. Retention also requires playback configuration, settings, localization, diagnostics, tests, notices, and resolved dependencies; traits alone are insufficient.
- Keep fork bundle IDs, signing, and app groups. Incoming iCloud entitlements and runtime container IDs must match the fork's provisioning; do not assume upstream's iCloud.com.gstudios.rivulet is usable by this fork.

## Branch roles (snapshot: 2026-11-06)

Existing upstream contribution branches: episode-selection-fix, hero-navigation-improvements, sidebar-improvements. Retain their remote names while PRs are open. Maintainer commits on those branches do not automatically reach fork main; check and integrate needed follow-ups deliberately.

Existing fork PR branches: feat/episode-poster-effects, fix/episode-detail-navigation, fix/metadata-badge-styling.

Parked experiments: feat/detail-motion and fix/scroll-animation-improvements. Do not resume or merge these without a request. The detail-motion WIP commit records unresolved season-row, focus/divider, and movie-animation issues.

For new branches, prefer contrib/ for upstream contributions, fork/ for fork-specific work, experiment/ for parked investigations, and sync/ for upstream integration. Do not rename existing published branches solely to enforce this convention.

## Audit context (2026-11-06; recheck before acting)

At the audit, upstream was 5454ea7e and fork main was 78901808: 34 upstream commits absent from the fork. Recompute these facts before integration. Update or remove this dated section and the branch snapshot as work lands; neither is a permanent task queue.

- Fork main and the hero contribution conflict in HeroButtonRowView.swift: upstream's 0.3-second Next-arrival guard overlaps our gesture-based guard. Resolve behavior deliberately.
- Episode-selection contribution conflicts in the relocated RivuletCore/Models/Media/EpisodePicker.swift: retain both showPlayTarget and upstream's nextEpisode/upNext helpers.
- Maintainer follow-up d7b8f9727aebe9246d3f0db262e9e7b93e5c5b8d fixes redundant/superseded loads, concurrent target fetching, and late rail repositioning. It was on the remote contribution branch but absent from fork main at audit time.
- AetherEngine 7.57.0 still declares the four traits. Restoring TrueHD requires resolving its dependency again; upstream's lockfile dropped LibTrueHD. Compatibility still needs build and device validation.

The proposed integration order is to resolve the two contribution conflicts against upstream main while preserving the maintainer's episode-loading fixes, then prepare a separate fork sync that includes those fixes, restores the retained Dolby features, and handles fork iCloud configuration. Build and test the combined result before proposing a merge. Leave the parked experiments alone.

This order is context, not standing authorization to perform the pending sync or PR updates. Confirm the current request's scope before proceeding.

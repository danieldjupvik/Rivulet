# Sidebar access from detail pages

Investigation recorded 2 November 2026. Deferred; no implementation or prototype yet.

Daniel verified that Apple's TV app allows opening its sidebar with Left from movie details and actor pages. Rivulet currently does not. Treat this as a separate navigation feature, not part of the small fixes on `fix/sidebar-polish`. Do not assume the sidebar should also open over players, alerts, authentication or every other screen.

## Scope and branch

Keep the completed fixes independently reviewable:

- `8c1f7f87`: prevent focus overshoot when closing the sidebar.
- `01905f0b`: keep the sidebar notch hidden below the top row.

Continue small sidebar polish on the current branch. Investigate detail-page access on a future branch such as `feat/detail-sidebar-navigation`, with a separate PR. Choose its base when work starts so the upstream diff contains only the intended changes. No branch has been created for this feature.

## What the source establishes

- `RootShellViewController` owns the sidebar and left-edge focus catcher. They live below presented detail controllers. Its Menu handler deliberately refuses input outside its own view hierarchy; weakening that guard would revive the hidden-sidebar/Menu bug documented in CLAUDE.md.
- `PreviewCarouselViewController` presents movie/show details using `.overFullScreen`. Actor pages use `PersonDetailViewController`, also presented `.overFullScreen`. Nested related-title and actor navigation can build several presentation levels.
- `ShellSidebarViewController` already supplies the shared appearance, sections and selection/collapse callbacks. Only the root shell currently instantiates it. The comment about a self-driven preview-modal path is not evidence of a working integration: selection callbacks are gated on `embedded`.
- `TVSidebarView` remains the tab/profile authority. Its selection binding rejects nested navigation and Settings sub-page changes. Profile switching uses a root SwiftUI full-screen cover, which needs explicit coordination if browsing presentations are still open.
- The carousel disables automatic focus restoration (`restoresFocusAfterTransition = false`) and has custom preferred-focus routing. Closing a sidebar must restore the actual prior control, not just request the page's default focus.
- Carousel exit paths include source-tile restoration and teardown callbacks. External stack dismissal has some support, but tab switching must verify cleanup and avoid leaving hidden source posters or restoring focus into an outgoing tab.

Plozz explains the architectural difference: its native sidebar is a `TabView(.sidebarAdaptable)` around tabs containing `NavigationStack`s. Movie and actor pages are pushed within those stacks. Its behavior does not demonstrate a drop-in modal-sidebar solution for Rivulet.

References: [Plozz sidebar](https://github.com/brandomoore/Plozz/blob/278ba3ade0a2734a81641aff771146cf506147a0/Sources/AppShell/MainTabView.swift#L1502), [detail and actor destinations](https://github.com/brandomoore/Plozz/blob/278ba3ade0a2734a81641aff771146cf506147a0/Sources/AppShell/HomeTab.swift#L486).

## Candidate approach to prototype

Keep existing detail presentations and UIKit surfaces. Reuse the sidebar implementation through one shared helper that eligible frontmost browsing pages can host. Prefer proper child-controller containment for an overlay within the detail page over adding another modal presentation just for the sidebar. Reuse the implementation and shared tab state; do not move the root shell's live child between parents or create an independent navigation authority.

The helper would coordinate left-edge entry, sidebar visibility, remembered focus and callbacks to the shell. Let ordinary focus navigation reach the edge so both touch swipes and arrow clicks work; do not claim every Left gesture. Movie preview-carousel paging must retain its Left/Right behavior. Initially consider only settled expanded details and actor pages, with access disabled during transitions and while another modal covers them.

Closing must preserve the detail page and its scroll position, restore the previous focused item, and prevent the closing swipe from overshooting. The root shell's existing gesture guard does not automatically cover modally presented details; reuse that policy deliberately.

This remains a feasibility proposal. The shared helper's size and integration cost are not established. Avoid a global window overlay, new window, private APIs or a rewrite into SwiftUI.

## Decisions and checks before implementation

- Verify Apple's behavior for selecting the current tab versus another tab while deep in details. Decide whether browsing history is discarded or retained; do not silently promise per-tab detail preservation.
- Coordinate tab selection with dismissal of only the relevant browsing stack, cleanup and the existing selection binding.
- Define profile selection and cancellation while details are open. Reuse the existing profile flow without conflicting presentations or losing the page unexpectedly.
- Keep Back behavior on the page unchanged when the sidebar is closed; explicitly define Back while it is open.
- Verify movie/show actions, lower detail rows, actors and nested related-title navigation; loading states; fresh and cached tabs; repeated opening/closing; both remote input transports; and focus restoration after closing.
- Exclude player controls, alerts, menus and authentication from automatic sidebar access.

## Apple guidance consulted

The Xcode documentation tool and Apple's HIG were consulted. These support the mechanisms, not a claim that Apple implements its TV app this way:

- [Focus interactions for Apple TV](https://developer.apple.com/documentation/uikit/about-focus-interactions-for-apple-tv) and [focusable elements](https://developer.apple.com/documentation/uikit/adding-user-focusable-elements-to-a-tvos-app): use the focus engine and geometric navigation; focus guides can redirect searches.
- [Custom container controllers](https://developer.apple.com/documentation/uikit/creating-a-custom-container-view-controller): use the documented child-controller lifecycle when composing interfaces.
- [Focus restoration](https://developer.apple.com/documentation/uikit/uiviewcontroller/restoresfocusaftertransition) and [UIFocusSystem](https://developer.apple.com/documentation/uikit/uifocussystem): restore/request focus through supported APIs, accounting for Rivulet's custom routing.
- [Over-full-screen presentation](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle/overfullscreen): underlying views remain in the hierarchy; that alone does not make the underlying sidebar accessible.
- [Dismissal](https://developer.apple.com/documentation/uikit/uiviewcontroller/dismiss(animated:completion:)): dismissal from lower in a presentation stack removes the controllers above it, which matters for tab changes.
- [Modality](https://developer.apple.com/design/human-interface-guidelines/modality): avoid unnecessary stacked modal experiences. This favors evaluating a contained sidebar overlay over another modal layer.
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars): sidebars provide navigation between major areas. The guidance does not mandate sidebar access on every page.

No source changes were made for this investigation. Runtime behavior of the proposed overlay remains untested.

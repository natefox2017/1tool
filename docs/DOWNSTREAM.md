# Downstream integration

This repository preserves the upstream Vorssaint app identity, UI, source paths,
license and history. `upstream` points to
https://github.com/vorssaint/vorssaint-utils; `origin` is our repository.

Super Right Click is a downstream addition. Its host service and shared protocol
live in `Sources/Vorssaint/Services/Finder/SuperRightClick*.swift`, its settings
view in `Sources/Vorssaint/UI/Settings/SuperRightClickSettings.swift`, and its
sandboxed Finder Sync extension in `Sources/FinderExtension`. The host performs
filesystem and application actions; the extension presents menus and sends
requests. Preferences and the feature availability gate use the existing app
infrastructure. The sidebar entry follows Super Key.

Synchronize by fetching `upstream` and merging `upstream/main` into a clean local
integration branch. Keep our commits on top of the shared history; do not replace
the checkout with an upstream snapshot. Resolve conflicts in the feature catalog,
settings routing and build packaging, then run the `super-right-click`, `features`,
`settings` and `preferences` test suites, build the app, run its selftest and check
the Finder menus. Review before merging into our main branch. Upstream additions
retain their original implementations and UI.

The app's built-in binary updater still follows upstream, as requested. Installing
an upstream binary does not include this repository's added features. Distribute
builds from this repository when the added Finder menus are required.

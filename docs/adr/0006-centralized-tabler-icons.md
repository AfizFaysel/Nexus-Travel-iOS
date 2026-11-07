# ADR-0006: Centralized Tabler icons

- Status: Accepted (amended 2026-11-07)
- Date: 2026-09-11

## Context

Android uses Tabler outline icons for travel objects. iOS used unrelated SF Symbols and feature screens could select raw symbol names, causing cross-platform visual drift.

## Decision

Bundle only the Tabler outline icons Nexus uses as SVG imagesets in `NexusIcons.xcassets` (MIT license in `TABLER-ICONS-LICENSE.txt`). Only the design-system icon module maps `NexusIconName` to them. Travel objects use Tabler outline icons; Apple navigation and platform actions keep SF Symbols.

Amendment: the `tabler-icons-swift` package (commit `41cfb5218c63420fea0d729a843b1dadd404ae63`) shipped all 5,611 icons, an 18 MB bundle, 70% of the Release app. It was removed and the 27 used icons were copied from it.

## Consequences

Icon source, rendering, accessibility, and future replacement stay local to one module. Adding a Tabler icon means copying its imageset from the Tabler set into `NexusIcons.xcassets` and adding the mapping case.

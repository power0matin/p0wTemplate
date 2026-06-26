# NeoTemplate Development Rules

## Repository Philosophy
- The repository must remain clean, lightweight, and production-ready.
- NEVER commit development artifacts, temporary files, internal documentation, docs/, drafts/, planning/, architecture notes, AI conversations, design documents, prototypes, experimental code, tests, local cache, generated zip files, IDE settings, or OS files.
- ONLY commit NeoTemplate source code, official themes, registry, installer, manager, lib, README, LICENSE, and CHANGELOG.

## Theme Development Standard
- Every theme must strictly follow the official package architecture. NO custom folder structures.
- Required structure:
  - `manifest.json`
  - `index.html`
  - `sub.html`
  - `assets/css/`, `assets/js/`, `assets/fonts/`, `assets/images/`
  - `preview.png`
  - `README.md`
- Themes must include a valid `manifest.json`, pass the NeoTemplate Validator, support official 3x-ui variables, use relative paths, and avoid external dependencies whenever possible.
- NEVER invent new directory layouts or unsupported manifest fields. NeoTemplate defines the standard.

## Preview Engine & Production Packaging Rules
- **Development Only**: The Preview Engine (`preview/` directory, `mock-data.json`, etc.) is strictly for local development and must NEVER be included in the production release.
- **Production Package**: A production package (ZIP) must only contain the files required by 3x-ui (`manifest.json`, `index.html`, `sub.html`, `assets/`, `README.md`).
- **Source of Truth**: The Preview Engine must not modify production files. The output in Preview Mode should simulate 3x-ui closely while remaining totally isolated from production architecture.

## Core Principles
- **Simplicity First**: NeoTemplate is designed to remain small, predictable, and maintainable. Do not introduce complexity unless it solves a real problem. Prefer simple architecture over clever architecture.
- **Single Responsibility**: Every module must have exactly one single responsibility.
- **Official Workflow**: The foundation of the ecosystem is strictly: Source → Preview → Validate → Build → Package → Release → Install. This workflow must remain consistent across all future versions.

## Development Roadmap & Theme Strategy
- **Phase 1**: NeoTemplate SDK. The official reference implementation and absolute source of truth.
- **Phase 2**: Neo Default Theme. The official reference implementation for developers (clean, modern, lightweight).
- **Phase 3**: Official Theme Collection. (Neo Glass, Apple, Minimal, Dashboard, etc.)

## Theme Design System Standard
- **Design First**: Before implementing HTML or CSS, define a complete Design System (Typography, Colors, Spacing, Radius, Elevation/Shadows, Buttons, Cards, Status Components, Progress Components, Icons, Animations, Transitions, Responsive Rules, Dark Mode Strategy).
- **Approval Required**: Implementation begins ONLY after the design system is approved.
- **Quality Levels**: Classify themes as Basic, Standard, Premium, or Signature.
- **Theme Personality**: Each theme must have its own unique personality, layout language, spacing system, and interaction style. Do not just swap colors.

## Theme Package Standard (Extended)
- Every official theme MUST include: `manifest.json`, `index.html`, `sub.html`, `assets/css/`, `assets/js/`, `assets/fonts/`, `assets/images/`, `README.md`, `CHANGELOG.md`, `LICENSE`, `preview.png`, `desktop-preview.png`, `mobile-preview.png`. No exceptions.

## Long-Term Theme Maintainability
- Never modify the SDK architecture to satisfy a single theme. Themes MUST adapt to the SDK.
- Themes must pass Validator, support Preview Engine, build, package, and install without manual modifications.
- Reusable components should remain inside the SDK whenever possible.

## NeoTemplate UI Design Principles
- **Information Priority**: Priority 1 (Most Important) must always be visible without scrolling: Subscription Display Name, Current Status, Remaining Traffic, Total Traffic, Remaining Time, Traffic Progress, Configuration List.
- **Display Name Priority**: Always prioritize the user's visible identity in the header (Display Name > Remark > Email > Username > Sub Name). Never prioritize Subscription ID.
- **Progressive Disclosure**: Use expandable sections (accordions) for Priority 3 technical info (Sub ID, Raw timestamps, internal identifiers).
- **User Experience Philosophy**: The interface should feel like a premium mobile application. Users should immediately see: Who am I? Is it active? How much traffic left? When does it expire? Where are my configs?
- **Consistency**: All official themes must follow this exact information hierarchy, even if colors, typography, and layouts drastically change.

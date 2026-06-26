# NeoTemplate SDK (Starter Theme)

The NeoTemplate SDK is the official reference implementation for all 3x-ui themes. It provides a clean, dependency-free, and highly extensible foundation for building custom subscription templates.

**Every future NeoTemplate theme must be built on top of this SDK.**

## Philosophy
- **No Build Tools**: No Webpack, no NPM, no React/Vue. Just pure HTML, CSS, and Vanilla JS.
- **CSS Variables First**: All styling must be driven by CSS variables in `assets/css/main.css`.
- **Modularity**: JS functions are modular and self-contained.
- **Strict Architecture**: You must not deviate from the directory structure outlined below.

## Folder Structure

```text
theme-starter/
├── manifest.json       # Required: Package identity and metadata
├── index.html          # Required: Main subscription template
├── sub.html            # Required: Alias/Copy of index.html
├── README.md           # Required: Documentation
├── CHANGELOG.md        # Required: Version history
├── LICENSE             # Required: Open source license
└── assets/             # Required: All static files MUST be inside this folder
    ├── css/
    │   └── main.css    # Core styles and variables
    ├── js/
    │   └── app.js      # Core logic and helpers
    ├── fonts/          # Local font files
    └── images/
        └── preview.png # Required: Thumbnail of the theme
```

## 3x-ui Template Variables
This template parses standard `html/template` variables injected by 3x-ui.

### Client Variables
- `{{ .client.Email }}`: The username/email of the subscriber.
- `{{ .client.Id }}`: The UUID of the client.
- `{{ .sId }}`: The subscription string ID.

### Subscription Object Variables
- `{{ .obj.Enable }}`: Boolean (true/false) determining if the subscription is active.
- `{{ .obj.Up }}`: Total uploaded data in bytes.
- `{{ .obj.Down }}`: Total downloaded data in bytes.
- `{{ .obj.Total }}`: Total allowed data limit in bytes (0 = unlimited).
- `{{ .obj.ExpiryTime }}`: Unix timestamp in milliseconds for expiration (0 = no expiry).

## Customization Guide

To create a new theme based on this SDK:
1. **Copy the SDK**: Duplicate this directory.
2. **Update Manifest**: Edit `manifest.json` with your new theme ID and details.
3. **Edit CSS Variables**: Open `assets/css/main.css` and change the `:root` variables to define your color palette, typography, and spacing.
4. **Modify HTML**: Edit `index.html` (and copy changes to `sub.html`) to change the layout, maintaining the semantic structure.

## Packaging and Releasing
When your theme is ready:
1. Ensure `manifest.json` is at the exact root of your folder.
2. Compress the folder into a `.zip` archive (e.g., `glass-1.0.0.zip`).
3. Ensure no extra root folders are inside the zip (the `manifest.json` should be in the root of the extracted zip, or exactly one folder deep).
4. Run it through the NeoTemplate Validator.

## Best Practices
- **Relative Paths**: Always use relative paths for assets (`assets/css/main.css`), never absolute paths (`/assets/...`).
- **Dark Mode**: Support the `.theme-dark` class and `prefers-color-scheme`.
- **Validation**: Test your zip with the NeoTemplate Package Manager before releasing.

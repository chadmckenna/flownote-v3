# CSS Guidelines (Fizzy-style)

These conventions are derived from how Basecamp's [Fizzy](https://github.com/basecamp/fizzy/tree/main/app/assets/stylesheets) structures its stylesheets. Follow them when writing or editing CSS in this project. They favor plain, modern, build-step-free CSS that works with Propshaft — no Sass, no PostCSS, no Tailwind.

## 1. File organization: one file per concern

- **Every component, utility group, or concern gets its own file**, named for what it styles: `buttons.css`, `cards.css`, `inputs.css`, `dialog.css`, `nav.css`, `flash.css`, etc.
- **Foundational files** carry generic names: `reset.css`, `base.css`, `layout.css`, `utilities.css`, `icons.css`, `animation.css`.
- **The global token/configuration file is `_global.css`** (leading underscore marks it as the foundational definitions file). It holds *only* `:root` custom properties, theme overrides, and the `@layer` order declaration — no actual rules that style elements.
- **Platform/native overrides** get their own files: `native.css`, `ios.css`, `android.css`, `pwa.css`, `print.css`.
- Keep files focused. A new UI concept = a new file, not a new section appended to an existing one.

## 2. Cascade layers are mandatory

Fizzy controls specificity through `@layer`, not selector weight.

- **`_global.css` declares the layer order once, at the very top:**
  ```css
  @layer reset, base, components, modules, utilities, native, platform;
  ```
  Order matters: later layers win regardless of selector specificity. Utilities beat components; platform overrides beat everything.
- **Every other file wraps its entire contents in the appropriate layer:**
  - `reset.css` → `@layer reset { … }`
  - `base.css`, `layout.css` → `@layer base { … }`
  - Components (`buttons.css`, `cards.css`, `inputs.css`, `icons.css`, …) → `@layer components { … }`
  - `utilities.css` → `@layer utilities { … }`
  - Platform files → `@layer native { … }` / `@layer platform { … }`
- When you add a file, decide its layer first and wrap everything in it.

## 3. Everything is driven by custom properties (design tokens)

`_global.css` is the single source of truth for design values. Define under `:root`, grouped with comment headers:

- **Spacing** uses a two-axis `inline`/`block` system with `half`/`double` modifiers:
  `--inline-space: 1ch`, `--block-space: 1rem`, plus `--inline-space-half`, `--block-space-double`, etc. derived with `calc()`.
- **Typography** uses a named t-shirt scale: `--text-xx-small` … `--text-xx-large`, plus `--font-sans`, `--font-serif`, `--font-mono`.
- **Color** is defined in **OKLCH**, in two tiers:
  1. Raw channel triplets as `--lch-*` (e.g. `--lch-blue-dark: 57% 0.19 260`), in a 7-step `darkest → lightest` ramp per hue.
  2. Named colors wrapping them: `--color-ink`, `--color-canvas`, `--color-link`, `--color-negative`, `--color-positive`, `--color-selected`, etc.
  Always reference the **named abstraction** (`var(--color-link)`) in components, never a raw `--lch-*` or a literal hex/rgb.
- **Z-index** is centralized as a named scale (`--z-nav`, `--z-flash`, `--z-tooltip`, …) so stacking order is legible in one place. Never hardcode arbitrary z-index integers in components.
- Other tokens: `--border`, `--shadow`, `--focus-ring`, named easing functions (`--ease-out-expo`), component sizes (`--btn-size`).

## 4. Theming via token reassignment, not duplicated rules

Dark mode is implemented by **redefining the `--lch-*` tokens**, not by rewriting component rules.

- Support both an explicit choice and the system preference, in two blocks:
  ```css
  html[data-theme="dark"] { /* redefine --lch-* tokens */ }

  @media (prefers-color-scheme: dark) {
    html:not([data-theme]) { /* same redefinitions */ }
  }
  ```
- Because components consume `--color-*` (which consume `--lch-*`), they re-theme automatically. Only reach into a component for a dark-mode tweak when a value genuinely can't be expressed as a token (e.g. a different `box-shadow` recipe).
- The same `data-theme` / `prefers-color-scheme` pair is the standard idiom anywhere a per-theme override is unavoidable.

## 5. Component API pattern: local custom properties with fallbacks

Each component exposes a **configurable API** through its own namespaced custom properties, consumed with a fallback default:

```css
.btn {
  --btn-border-radius: 99rem;
  background-color: var(--btn-background, var(--color-canvas));
  border: var(--btn-border-size, 1px) solid var(--btn-border-color, var(--color-ink-light));
  color: var(--btn-color, var(--color-ink));
  padding: var(--btn-padding, 0.5em 1.1em);
}
```

- **Variants are pure token overrides** — they set the component's local properties and nothing else:
  ```css
  .btn--negative {
    --btn-background: var(--color-negative);
    --btn-border-color: var(--color-negative);
    --btn-color: var(--color-ink-inverted);
  }
  ```
- This keeps variants tiny, composable, and free of `!important` specificity wars. Prefer adding a `--component-*` knob over writing a new override rule.

## 6. Naming: BEM-ish, lowercase, hyphenated

- **Block**: `.card`, `.btn`, `.input`, `.switch`.
- **Element**: double underscore — `.card__header`, `.card__body`, `.card__meta-text`, `.btn__group`.
- **Modifier/variant**: double dash — `.btn--negative`, `.card--notification`, `.input--select`, `.input--textarea`.
- Local custom properties are namespaced to their block: `--btn-*`, `--card-*`, `--input-*`, `--switch-*`.
- All class names are lowercase and hyphenated; multi-word element/modifier segments use single hyphens (`card__meta-text--added`).

## 7. Utilities are single-purpose and live in `utilities.css`

- Utility classes do one thing: `.flex`, `.flex-column`, `.gap`, `.full-width`, `.txt-small`, `.txt-subtle`, `.pad-block`, `.margin-inline-end`, `.border-radius`, `.shadow`, `.visually-hidden`.
- They map directly onto the design tokens (`.txt-small { font-size: var(--text-small); }`, `.pad { padding: var(--block-space) var(--inline-space); }`).
- Naming families: `txt-*` (text), `font-weight-*`, `pad-*` / `unpad-*`, `margin-*`, `fill-*` (background), `flex-*` / `justify-*` / `align-*`, `border-*`, `hide-*` / `show-*` (visibility).
- Because they're in the `utilities` layer, they reliably override component styles without `!important` (reserve `!important` for genuinely unconditional cases like `[hidden] { display: none !important; }`).

## 8. Modern CSS idioms — use them by default

- **Logical properties everywhere**: `inline-size`/`block-size` (not width/height), `margin-inline`, `padding-block`, `inset`, `border-inline-start`, `margin-block-start`. This is non-negotiable in Fizzy CSS — it's how RTL and writing modes stay correct.
- **Nesting**: native CSS nesting with `&` for states, children, and contextual overrides. No Sass.
  ```css
  .btn {
    &[disabled] { opacity: 0.3; }
    @media (any-hover: hover) { &:hover { filter: brightness(0.9); } }
    html[data-theme="dark"] & { --btn-hover-brightness: 1.25; }
  }
  ```
- **`color-mix()`** for derived shades instead of pre-defining every tint: `color-mix(in srgb, var(--card-color) 30%, var(--color-ink))`.
- **`:where()` / `:is()`** to keep specificity low (especially `:where(:focus-visible)`) and to group selectors.
- **`:has()`** for parent/state-driven styling (`.btn:has(input:checked)`, `.input--upload:has([data-upload-preview-target="fileName"]:not([hidden]))`).
- **`clamp()`** for fluid sizing (`--main-padding: clamp(var(--inline-space), 3vw, calc(var(--inline-space) * 3))`).
- **`@supports`** to progressively enhance (`field-sizing: content`, etc.).

## 9. Accessibility and interaction are built in

- Centralize focus styling via `--focus-ring-*` tokens and apply with `:focus-visible` + `outline` (never remove focus outlines without a replacement). A `.hide-focus-ring` utility sets `--focus-ring-size: 0` for the rare opt-out.
- Honor `@media (prefers-reduced-motion: reduce)` in the reset — neutralize animations/transitions globally.
- Provide `.visually-hidden` / `.for-screen-reader` for screen-reader-only content.
- Gate hover effects behind `@media (any-hover: hover)` so touch devices don't get stuck hover states; use `.hide-on-touch` / `.show-on-touch` for input-modality differences.
- Respect disabled state consistently (`cursor: not-allowed; opacity; pointer-events: none`).

## 10. Responsive & platform conventions

- Mobile breakpoints cluster around `max-width: 639px` / `min-width: 640px`; layout breakpoints around `799px`/`800px`. Reuse these, don't invent new ones per component.
- Account for device safe areas through `--custom-safe-inset-*` tokens (which wrap `env(safe-area-inset-*)`), not raw `env()` calls scattered in components.
- Native/PWA differences are handled with `[data-platform~="native"]`, `@media (display-mode: standalone)`, and the dedicated platform files/layers — keep them out of core component files.

## 11. In-file formatting

- Properties within a rule are **alphabetized** (custom-property declarations come first, then standard properties).
- Use comment banners to section larger files:
  ```css
  /* Variants
  /* ------------------------------------------------------------------------ */
  ```
- Group `:root` tokens under `/* Spacing */`, `/* Text */`, `/* Colors: Named */`, etc.
- Add explanatory comments for non-obvious hacks (browser-specific workarounds, "FF fix", Safari quirks).

---

### Quick checklist when adding/editing CSS

1. New concern → new file, named for it.
2. Wrap the file in the correct `@layer`.
3. Reach for an existing token (`--color-*`, `--*-space`, `--text-*`, `--z-*`) before introducing a value; add new tokens to `_global.css`, not inline literals.
4. Expose component config as `--block-name-*` properties with `var(…, default)` fallbacks; make variants override those properties only.
5. Use logical properties, native nesting, `:where()`/`:is()`/`:has()`, and `color-mix()`.
6. Theme by reassigning tokens under `html[data-theme="dark"]` + the `prefers-color-scheme` fallback.
7. Keep specificity low; let layers and utilities do the overriding instead of `!important`.
8. Alphabetize properties; banner-comment sections.

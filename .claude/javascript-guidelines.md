# JavaScript Guidelines (Fizzy-style)

These conventions are derived from how Basecamp's [Fizzy](https://github.com/basecamp/fizzy/tree/main/app/javascript) structures its client-side JavaScript. Follow them when writing or editing JS in this project. They favor plain, modern, build-step-free JavaScript loaded through importmap and orchestrated by Hotwire (Turbo + Stimulus) — no npm, no bundler, no client-side framework.

This aligns with the project's guiding principles: **Rails way first**, **server-side first** (Turbo/Stimulus over client logic), and **keep it simple**.

## 1. No build step — importmap only

- All JavaScript is plain ES modules loaded via `importmap-rails`. There is **no Node.js, no npm, no bundler, no transpile step**. Propshaft serves the files as-is.
- Add third-party packages by pinning them in `config/importmap.rb` (e.g. `bin/importmap pin <pkg>`), never via `package.json`.
- Use modern syntax browsers support natively: ES modules, `async`/`await`, optional chaining (`?.`), nullish coalescing (`??`), class fields, and **private class members (`#field` / `#method()`)**. Don't reach for anything that would require compilation.

## 2. Directory layout: four roles

Mirror Fizzy's top-level structure under `app/javascript/`:

- **`application.js`** — the entry point. Imports the framework deps (`@hotwired/turbo-rails`), then `"controllers"`, then `"initializers"` (if present), then any libraries. Keep it to imports plus a tiny amount of global wiring (e.g. registering a custom `Turbo.StreamActions`).
- **`controllers/`** — Stimulus controllers, one `*_controller.js` per concern. This is where the overwhelming majority of code lives.
- **`helpers/`** — small, **stateless pure functions** exported for reuse across controllers (timing, platform detection, DOM/text/form utilities). No DOM-bound state, no Stimulus.
- **`initializers/`** — one-time setup that runs at import time (global singletons, event-listener bootstrapping, third-party element registration). Imported via an `initializers/index.js` barrel.
- **`lib/`** — self-contained integrations / vendored-style modules that don't fit the above (e.g. an auth/passkey wrapper).

Create `helpers/`, `initializers/`, or `lib/` only when you actually have something to put there — don't scaffold empty dirs.

## 3. Controller registration is automatic

Keep the two boilerplate files exactly as Rails/Fizzy generate them:

```js
// controllers/application.js
import { Application } from "@hotwired/stimulus"
const application = Application.start()
application.debug = false
window.Stimulus = application
export { application }
```

```js
// controllers/index.js
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
```

- Controllers are **eager-loaded by convention** — a file at `controllers/foo_controller.js` auto-registers as the `foo` identifier (`data-controller="foo"`). Nested dirs use double dashes: `controllers/bridge/form_controller.js` → `bridge--form`.
- Don't manually register controllers or pin them individually in the importmap.

## 4. Anatomy of a Stimulus controller

Every controller is an anonymous `export default class extends Controller`. Order its members consistently:

1. Private instance fields (`#hiddenField`) at the very top.
2. **Static API declarations** — `static targets`, `static values`, `static classes`, `static outlets` — these are the controller's public contract with the HTML.
3. **Lifecycle callbacks** — `connect()`, `disconnect()`, then target callbacks (`fooTargetConnected()`).
4. **Public action methods** (the verbs referenced by `data-action`).
5. **Private helpers** (`#methodName()`) and private getters/setters last.

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "checkbox" ]
  static classes = [ "toggle" ]
  static values  = { content: String }

  toggle() {
    this.element.classList.toggle(this.toggleClass)
  }

  #submitElements() {
    return this.element.querySelectorAll("input[type=submit],button")
  }
}
```

Formatting matches the surrounding files: 2-space indent, double quotes, no semicolons, spaces inside array literals (`[ "toggle" ]`).

## 5. State lives in the DOM and HTML attributes — read it, don't hoard it

Controllers are **thin behavior attached to server-rendered HTML**, not state containers.

- Prefer reading current state from the DOM (attributes, `classList`, `checked`, `value`, `getComputedStyle`) over caching it in instance variables.
- Drive configuration through Stimulus **values** (`static values = { modal: { type: Boolean, default: false } }`) so the server controls behavior via `data-*-value` attributes.
- Drive styling hooks through Stimulus **classes** (`static classes = [ "success" ]`) so class names stay in the HTML, not hardcoded in JS.
- Use **targets** to find elements; never `document.querySelector` for something inside your own controller's scope.
- Persist genuinely client-only preferences in `localStorage` (theme, dismissed hints) — that's the one acceptable client-side store.

## 6. Private-by-default

- Anything not called from `data-action` or a Stimulus lifecycle hook is a **private `#method()`, `#field`, or `get #thing()` / `set #thing()`**. Fizzy uses private getters/setters heavily to model derived state (`get #selectedItem()`, `set #theme(value)`).
- Keep the public surface (action verbs) small and intention-revealing: `open()`, `close()`, `copy()`, `submit()`.
- Private helpers should read like prose and do one thing: `#markAsBusy()`, `#disableSubmit()`, `#forceReflow()`.

## 7. Helpers are pure, named, single-purpose functions

Anything reusable and stateless goes in `helpers/` as a **named export** (not default), grouped by theme into one file:

```js
// helpers/timing_helpers.js
export function debounce(fn, delay = 1000) { /* … */ }
export function nextFrame() { return new Promise(requestAnimationFrame) }
export function delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)) }
```

- Group by domain: `timing_helpers.js`, `platform_helpers.js`, `html_helpers.js`, `form_helpers.js`, `text_helpers.js`, etc. — name the file `<domain>_helpers.js`.
- Import them where needed: `import { isTouchDevice } from "helpers/platform_helpers"`.
- Helpers must not touch Stimulus or hold mutable module state. Promise-returning timing helpers (`nextFrame`, `nextEvent`, `delay`) are the idiomatic way to await DOM/async moments — prefer them over inline `setTimeout`/`addEventListener` plumbing.

## 8. Initializers for one-time global setup

Code that must run once at boot (not per-element) lives in `initializers/` and is pulled in through a barrel:

```js
// initializers/index.js
import "initializers/current"
import "initializers/offline"
```

- Use this for global singletons exposed on `window` (e.g. a `Current` object that reads `<meta>` tags), registering custom elements, or attaching app-wide listeners.
- Read server-provided context from `<meta>` tags rather than inlining `<script>` data:
  ```js
  document.head.querySelector(`meta[name="current-user-id"]`)?.getAttribute("content")
  ```

## 9. Lean on Hotwire; reach for `fetch` rarely

- **Turbo first.** Let Turbo Drive, Frames, and Streams handle navigation, partial updates, and form submission. Listen for Turbo lifecycle events (`turbo:submit-end`, `turbo:before-stream-render`) instead of hand-rolling XHR + DOM patching.
- When you must submit programmatically, use the native form API (`this.element.requestSubmit()`) or `@rails/request.js` (`FetchRequest`) — wrapped in a helper like `submitForm(form)`. Don't sprinkle raw `fetch` + `FormData` across controllers.
- Custom Turbo Stream actions (e.g. `Turbo.StreamActions.advance_url`) are the right escape hatch for "Turbo can't express this" — register them in `application.js` and keep them tiny.

## 10. Lifecycle hygiene & accessibility

- **Tear down what you set up.** Anything added in `connect()` (global listeners, `MutationObserver`, intervals) must be removed in `disconnect()`. Bind a handler once and store the reference so you can remove the same function:
  ```js
  connect()    { this.handler ||= this.onUnload.bind(this); window.addEventListener("beforeunload", this.handler) }
  disconnect() { window.removeEventListener("beforeunload", this.handler) }
  ```
- Prefer `{ once: true }` for one-shot listeners so they clean themselves up.
- Keep ARIA state in sync from JS: toggle `aria-busy`, `aria-hidden`, `aria-checked`, `disabled` as state changes (see `auto_submit`, `dialog`, `combobox`).
- Respect user preferences and input modality: check `prefers-reduced-motion` before animating, use `startViewTransition` only when available and motion is allowed, and branch on `isTouchDevice()` for touch-vs-pointer behavior.
- Use feature detection (`document.startViewTransition?`, `window.matchMedia?.(…)`) and fail soft (`try { await navigator.clipboard.writeText(…) } catch {}`) rather than assuming API availability.

## 11. Native bridge code stays isolated

If/when Hotwire Native is in play, bridge controllers live in `controllers/bridge/`, extend `BridgeComponent`, declare `static component`, and call `super.connect()` / `super.disconnect()`. Keep all native-specific concerns in that subtree — core controllers should not know whether they're running in a native shell. (Mirror this for any other platform-specific JS.)

---

### Quick checklist when adding/editing JS

1. New behavior → a Stimulus controller in `controllers/`, named `<concern>_controller.js`. Reusable stateless logic → a named export in `helpers/<domain>_helpers.js`.
2. Declare the HTML contract up top with `static targets` / `values` / `classes`; read state from the DOM, don't cache it.
3. Public surface = the verbs in `data-action`. Everything else is `#private`.
4. No new npm/build deps — pin in `config/importmap.rb`; use only browser-native modern syntax.
5. Let Turbo handle navigation/forms/streams; only drop to `requestSubmit()`/`FetchRequest` when Turbo genuinely can't.
6. Clean up every listener/observer in `disconnect()`; prefer `{ once: true }`.
7. Keep ARIA attributes in sync; gate motion behind `prefers-reduced-motion`; feature-detect and fail soft.
8. 2-space indent, double quotes, no semicolons, `[ "spaced" ]` array literals.

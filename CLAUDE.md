# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlownoteV3 is a Rails 8.1 application (Ruby 4.0.2) that provides user authentication and an OAuth 2.0 provider for CLI applications. It uses SQLite3 for all storage (including cache, queue, and websockets via Solid Queue/Cache/Cable) — no Redis or Postgres required.

## Guiding Principles

- **Rails way first.** Use generators and built-in Rails functionality before reaching for gems or writing custom code.
- **Server-side first.** Do things server-side whenever possible using Turbo and Stimulus. Avoid client-side JS frameworks or heavy client logic.
- **Keep it simple.** This service should stay clutter-free and fast. Resist unnecessary abstractions, dependencies, and complexity.
- And most important: **Keep it simple-er.** When designing and making changes, always think about making the smallest change possible. Less code === less problems.

## Commands

```bash
bin/setup                              # Install deps + setup DB
bin/dev                                # Start dev server (port 3000)
bin/rails test                         # Run all tests
bin/rails test test/path/file.rb       # Run single test file
bin/rails test test/path/file.rb:10    # Run test at specific line
bin/rails test:system                  # System tests (Capybara + Selenium)
bin/rubocop                            # Lint (rubocop-rails-omakase style)
bin/rubocop -a                         # Lint with autofix
bin/brakeman                           # Security analysis
bin/ci                                 # Full CI pipeline
```

## Architecture

**Stack**: Rails 8.1, Propshaft (no Node.js), Hotwire (Turbo + Stimulus), [Oat CSS](https://oat.ink/) (classless), SQLite3, Doorkeeper (OAuth 2.0).

**Authentication**: Session-based with signed cookies. `Current` singleton for thread-safe session/user access. `Authentication` concern on ApplicationController. Rate-limited login/password-reset (10 per 3 min).

**OAuth 2.0 Provider**: Doorkeeper gem. Authorization code flow with PKCE required. Scopes: `:read` (default), `:write`. First-party public CLI apps skip consent. 30-day token expiration.

**API layer**: `Api::V1::BaseController` inherits `ActionController::API` (not `ActionController::Base`). All API endpoints require `doorkeeper_authorize!`. `current_user` comes from the Doorkeeper token's resource owner.

**JavaScript**: Stimulus controllers in `app/javascript/controllers/` loaded via importmap — no npm, no build step.

**CSS**: Oat classless framework from CDN styles semantic HTML by default. Custom styles go in `app/assets/stylesheets/`.

**Editor UI navigation (folders/notes)**: Morphing-first, no navigation frames. Sidebar / breadcrumb / View / Edit / Close are plain Turbo Drive links (full-page visits). Same-URL refreshes — save redirects and `broadcasts_refreshes` — morph (`turbo-refresh-method=morph` is set in `layouts/shared/_head`); cross-URL visits replace `<body>`. **Never put navigable content or persistent chrome in a Turbo Frame defined in the layout**: turbo-rails substitutes a minimal `turbo_rails/frame` layout on `Turbo-Frame` requests, so layout-defined frames disappear ("Content missing"). The shell (`topnav/context` + `sidebar/sidebar` + `.folder-shell__main`) renders fully on every visit; `app/views/layouts/application.html.erb` branches on `folder_shell?` (set by `ShellLoader#load_shell`). Turbo Frames are reserved for inline forms only (`new_note`, `new_folder`, `edit_folder_<id>`). The CodeMirror editor (`vim_editor_controller`) is wrapped with a per-note `id` plus a `turbo:before-morph-element` guard, so a live-refresh morph preserves unsaved text while switching notes recreates it. Live updates: `broadcasts_refreshes` on `Note`/`Folder` + `turbo_stream_from @folder`/`@note` in the shell.

**Testing**: Minitest with parallel workers. Fixtures auto-loaded. Test helpers: `SessionTestHelper` (`sign_in_as`, `sign_out`) and `ApiTestHelper` (`create_oauth_application`, `create_access_token`, `api_headers`).

**Background jobs**: Solid Queue (database-backed). Runs in-process with Puma via `SOLID_QUEUE_IN_PUMA` env var in production.

**Deployment**: Kamal with Docker. Thruster provides HTTP caching/compression. Persistent volume for SQLite files.

## Key Routes

- `POST/DELETE /session` — login/logout
- `POST /registration` — signup
- `POST /passwords`, `PATCH /passwords/:token` — password reset flow
- `POST /oauth/authorize`, `POST /oauth/token` — OAuth flow
- `GET /api/v1/me` — current user (OAuth-protected)
- `GET /up` — health check

# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project

FlownoteV3 — a Rails 8.1 application using Ruby 4.0.2, SQLite3, and Hotwire (Turbo + Stimulus).

## Commands

- **Dev server:** `bin/dev`
- **Console:** `bin/rails console`
- **Run all tests:** `bin/rails test`
- **Run a single test file:** `bin/rails test test/models/user_test.rb`
- **Run a single test by line:** `bin/rails test test/models/user_test.rb:10`
- **System tests:** `bin/rails test:system`
- **Lint:** `bin/rubocop` (Rails Omakase style)
- **Lint with autofix:** `bin/rubocop -a`
- **Security scan:** `bin/brakeman`
- **Gem audit:** `bundle exec bundler-audit check`
- **DB setup:** `bin/rails db:setup`
- **DB migrate:** `bin/rails db:migrate`

## Architecture

- **Asset pipeline:** Propshaft (not Sprockets). No Node.js or npm — JS is managed via importmap (`config/importmap.rb`).
- **Frontend:** Hotwire stack — Turbo for navigation/frames/streams, Stimulus for JS controllers (`app/javascript/controllers/`).
- **CSS:** Oat — a classless CSS framework that styles semantic HTML elements by default. No classes needed for basic styling. Component documentation and examples: https://oat.ink/components/
- **Background jobs:** Solid Queue (database-backed, no Redis needed).
- **Caching:** Solid Cache (database-backed).
- **WebSockets:** Solid Cable (database-backed).
- **Database:** SQLite3 for all environments. Production uses separate SQLite databases for cache, queue, and cable (`config/database.yml`).
- **Deployment:** Kamal with Thruster (HTTP caching/compression layer in front of Puma).

## Testing

Uses Minitest (Rails default). System tests use Capybara with Selenium WebDriver. Test files mirror app structure under `test/`.

## Style

RuboCop is configured with `rubocop-rails-omakase` — the Rails team's default ruleset. See `.rubocop.yml` for any local overrides.

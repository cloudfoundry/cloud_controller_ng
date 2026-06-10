# 15: Using FactoryBot for Factories

Date: 2026-05-23

## Status

Accepted (supersedes [ADR 0002](0002-using-machinist-for-factories.md))

## Context

[ADR 0002](0002-using-machinist-for-factories.md) (2019) decided to keep
[machinist][machinist] after a partial migration to [factory_bot][factory_bot]
hit friction with Sequel's mutual-foreign-key associations. Seven years later,
the situation has shifted:

* `machinist` 1.0.6 has had no upstream activity since 2013. The "maintained
  fork" mentioned in 0002 never materialised in a way that this project
  consumed.
* `machinist` 2.0 exists but is not a viable upgrade. It removed the Sequel
  adapter we depend on, dropped `Sham`, and flipped `make` from a persisting
  call to a non-persisting one — every existing call site would change
  meaning.
* `factory_bot` is actively maintained and well-known to anyone joining a
  Ruby project.
* The blocker described in 0002 — Sequel's mutual-foreign-key pattern, where
  two records reference each other — turns out to be solvable cleanly in
  `factory_bot` once a global `to_create` and `after(:create)` callbacks
  with transient flags are used. None of these primitives required a special
  Sequel adapter.

## Decision

Replace `machinist` with `factory_bot` as the test-data framework. The
`machinist` gem and its supporting files (`spec/support/fakes/blueprints.rb`,
`spec/support/machinist_monkey_patch.rb`) are removed; ~11k call sites of
`Klass.make(...)` and `Klass.make_unsaved(...)` are converted to
`create(:klass, ...)` and `build(:klass, ...)`; and ~130 blueprints become
factory definitions under `spec/support/factory_definitions/`.

The conversion is done as one change. There is no extended period in which
both libraries coexist in the codebase.

### Key technical decisions

The patterns below are what made the 2019 friction tractable.

* **Global `to_create { |i| i.save; i.refresh }`** in
  `spec/support/factories.rb`. This matches machinist's Sequel adapter,
  which both saved and refreshed. Without the refresh, tests that mutate
  associations after creation see Sequel's stale in-memory association
  cache rather than the current DB state.

* **`Sham` is preserved as a thin shim** (`spec/support/sham_shim.rb`) that
  delegates `Sham.<name>` to `FactoryBot.generate(:sham_<name>)` sequences
  defined in `spec/support/factories.rb`. The shim mirrors the original
  `Sham.define` block 1:1, so existing call sites need no edits.

* **Dynamic class → factory-name conversion** via
  `klass.name.demodulize.underscore.to_sym` is used in matchers and
  shared examples, so generic helpers continue to look up the right
  factory when given any model class.

* **Named blueprints become traits** — `Foo.blueprint(:bar)` turns into a
  `trait :bar` on the `:foo` factory. Call sites move from
  `Foo.make(:bar, x: 1)` to `create(:foo, :bar, x: 1)`.

* **`build` replaces `make_unsaved`** for the (rare) cases that wanted an
  unsaved instance.

* **`:droplet_model` only auto-sets itself as the app's current droplet
  when no `app:` override is supplied** (`set_as_current_droplet { app == :unset }`),
  matching machinist's blueprint where the default `app` block only ran in
  that case. Specs that previously relied on the auto-set side effect when
  passing `app:` explicitly call `app.update(droplet:)`, just as the
  pre-migration versions did.

* **`:revision_sidecar_process_type_model` builds its parent with the
  `:no_process_types` trait** so `FactoryBot.lint` does not collide with
  the parent's `after_create` web row on the
  `(revision_sidecar_guid, type)` unique constraint.

## Consequences

* New contributors no longer need to learn `machinist` first; `factory_bot`
  is the de-facto Ruby standard.
* The `machinist 1.0.6` dependency and its dependabot churn are gone.
* `factory_bot` is actively maintained, so most future test-framework
  upgrades happen via `bundle update` rather than via a custom monkey
  patch (as `machinist_monkey_patch.rb` had to do).
* Tooling that reasoned about `machinist` blueprints (e.g. spec generators,
  custom rubocop cops) needs to be updated; none of it lived in this
  repository.

## Alternatives Considered

* **Stay on `machinist 1.0.6`.** Rejected: unmaintained upstream, dependabot
  noise, and the risk that some future Ruby/Sequel upgrade silently breaks
  the gem.
* **Upgrade to `machinist 2.0`.** Rejected: no Sequel adapter, no `Sham`,
  and `make` no longer persists — the upgrade is effectively a rewrite of
  every call site for less benefit than moving to `factory_bot`.
* **Adopt a maintained fork of `machinist`.** No fork with meaningful
  activity exists, and adopting one trades one unmaintained dependency for
  another small one.

[machinist]: https://github.com/notahat/machinist
[factory_bot]: https://github.com/thoughtbot/factory_bot

# RSpec::Wait

Time-resilient expectations in RSpec

[![Made by laserlemon](https://img.shields.io/badge/laser-lemon-fc0?style=flat-square)](https://github.com/laserlemon)
[![Gem version](https://img.shields.io/gem/v/rspec-wait?style=flat-square)](https://rubygems.org/gems/rspec-wait)
[![Build status](https://img.shields.io/github/actions/workflow/status/laserlemon/rspec-wait/test.yml?style=flat-square)](https://github.com/laserlemon/rspec-wait/actions/workflows/test.yml)


## Why does RSpec::Wait exist?

Timing is hard.

Timing problems and race conditions can plague your test suite. As your test
suite slowly becomes less reliable, development speed and quality suffer.

RSpec::Wait strives to make it easier to test asynchronous or slow interactions.

## How does RSpec::Wait work?

RSpec::Wait allows you to wait for an assertion to pass, using the RSpec
syntactic sugar that you already know and love.

RSpec::Wait will keep trying until your assertion passes or times out.

### Examples

RSpec::Wait's `wait_for` assertions are nearly drop-in replacements for RSpec's
`expect` assertions. The major difference is that the `wait_for` method
requires a block because it may need to evaluate the content of that block
multiple times while it's waiting.

```ruby
RSpec.describe Ticker do
  subject(:ticker) { Ticker.new("foo") }

  describe "#start" do
    before do
      ticker.start
    end

    it "starts with a blank tape" do
      expect(ticker.tape).to eq("")
    end

    it "sends the message in Morse code one letter at a time" do
      wait_for { ticker.tape }.to eq("··-·")
      wait_for { ticker.tape }.to eq("··-· ---")
      wait_for { ticker.tape }.to eq("··-· --- ---")
    end
  end
end
```

RSpec::Wait can be especially useful for testing user interfaces with tricky
timing elements like JavaScript interactions or remote requests.

```ruby
feature "User Login" do
  let!(:user) { create(:user, email: "john@example.com", password: "secret") }

  scenario "A user can log in successfully" do
    visit new_session_path

    fill_in "Email", with: "john@example.com"
    fill_in "Password", with: "secret"
    click_button "Log In"

    wait_for { current_path }.to eq(account_path)
    expect(page).to have_content("Welcome back!")
  end
end
```

## Compatibility

### Ruby Support

RSpec::Wait is tested against all [non-EOL Ruby versions](https://www.ruby-lang.org/en/downloads/branches/),
which as of this writing are versions 3.1, 3.2, and 3.3. If you find that
RSpec::Wait does not work or [is not tested](https://github.com/laserlemon/rspec-wait/blob/-/.github/workflows/rake.yml)
for a maintained Ruby version, please [open an issue](https://github.com/laserlemon/rspec-wait/issues/new)
or pull request to add support.

Additionally, RSpec::Wait is tested against Ruby head to surface future
compatibility issues, but no guarantees are made that RSpec::Wait will
function as expected on Ruby head. Proceed with caution!

### RSpec Support

RSpec::Wait is tested against several [versions of RSpec](https://rubygems.org/gems/rspec/versions),
which as of this writing are versions 3.4 through 3.13. If you find that
RSpec::Wait does not work or [is not tested](https://github.com/laserlemon/rspec-wait/blob/-/.github/workflows/rake.yml)
for a newer RSpec version, please [open an issue](https://github.com/laserlemon/rspec-wait/issues/new)
or pull request to add support.

Additionally, RSpec::Wait is tested against unbounded RSpec to surface future
compatibility issues, but no guarantees are made that RSpec::Wait will
function as expected on any RSpec version that's not explicitly [tested](https://github.com/laserlemon/rspec-wait/blob/-/.github/workflows/rake.yml).
Proceed with caution!

### Matchers

RSpec::Wait ties into RSpec's internals so it can take full advantage of any
matcher that you would use with RSpec's own `expect` method.

If you discover a matcher that works with `expect` but not with `wait_for`,
please [open an issue](https://github.com/laserlemon/rspec-wait/issues/new)
and I'd be happy to take a look!

## Installation

To get started with RSpec::Wait, simply add the dependency to your `Gemfile`
and `bundle install`:

```ruby
gem "rspec-wait", "~> 1.0"
```

If your codebase calls `Bundler.require` at boot time, you're all set and the
`wait_for` method is already available in your RSpec suite.

If you encounter the following error:

```
NoMethodError:
  undefined method `wait_for'
```

You will need to explicitly require RSpec::Wait at boot time in your test
environment:

```ruby
require "rspec/wait"
```

### Upgrading from v0

RSpec::Wait v1 is very similar in syntax to v0 but does have a few breaking
changes that you should be aware of when upgrading from any 0.x version:

1. RSpec::Wait v1 requires Ruby 3.0 or greater and RSpec 3.4 or greater.
2. The `wait_for` and `wait.for` methods no longer accept arguments, only
   blocks.
3. RSpec::Wait no longer uses Ruby's problematic `Timeout.timeout` method,
   which means it will no longer raise a `RSpec::Wait::TimeoutError`.
   RSpec::Wait v1 never interrupts the block given to `wait_for` mid-call
   so make every effort to reasonably limit the block's individual call time.

## Configuration

RSpec::Wait has three available configuration values:

- `wait_timeout` - The maximum amount of time (in seconds) that RSpec::Wait
  will continue to retry a failing assertion. Default: `10.0`
- `wait_delay` - How long (in seconds) RSpec::Wait will pause between retries.
  Default: `0.1`
- `clone_wait_matcher` - Whether each retry will `clone` the given RSpec
  matcher instance for each evaluation. Set to `true` if you have trouble with
  a matcher holding onto stale state. Default: `false`

RSpec::Wait configurations can be set in three ways:

- Globally via `RSpec.configure`
- Per example or context via RSpec metadata
- Per assertion via the `wait` method

### Global Configuration

```ruby
RSpec.configure do |config|
  config.wait_timeout = 3 # seconds
  config.wait_delay = 0.5 # seconds
  config.clone_wait_matcher = true
end
```

### RSpec Metadata

Any of RSpec::Wait's three configurations can be set on a per-example or
per-context basis using `wait` metadata. Provide a hash containing any
number of shorthand keys and values for RSpec::Wait's configurations.

```ruby
scenario "A user can log in successfully", wait: { timeout: 3, delay: 0.5, clone_matcher: true } do
  visit new_session_path

  fill_in "Email", with: "john@example.com"
  fill_in "Password", with: "secret"
  click_button "Log In"

  wait_for { current_path }.to eq(account_path)
  expect(page).to have_content("Welcome back!")
end
```

### The `wait` Method

And on a per-assertion basis, the `wait` method accepts a hash of shorthand
keys and values for RSpec::Wait's configurations. The `wait` method must be
chained to the `for` method and aside from the ability to set RSpec::Wait
configuration for the single assertion, it behaves identically to `wait_for`.

```ruby
scenario "A user can log in successfully" do
  visit new_session_path

  fill_in "Email", with: "john@example.com"
  fill_in "Password", with: "secret"
  click_button "Log In"

  wait(timeout: 3).for { current_path }.to eq(account_path)
  expect(page).to have_content("Welcome back!")
end
```

The `wait` method will also accept `timeout` as a positional argument for
improved readability:

```ruby
wait(3.seconds).for { current_path }.to eq(account_path)
```

## Use with RuboCop

If you use `rubocop` and `rubocop-rspec` in your codebase, an RSpec example
with a single `wait_for` assertion may cause RuboCop to complain:

```
RSpec/NoExpectationExample: No expectation found in this example.
```

By default, RuboCop sees only `expect*` and `assert*` methods as expectations.
You can configure RuboCop to recognize `wait_for` and `wait.for` as
expectations (in addition to the defaults) in your RuboCop configuration:

```yaml
RSpec/NoExpectationExample:
  AllowedPatterns:
  - ^assert_
  - ^expect_
  - ^wait(_for)?$
```

Of course, you can always disable this cop entirely:

```yaml
RSpec/NoExpectationExample:
  Enabled: false
```

## Use with Cucumber

To enable RSpec::Wait in your Cucumber step definitions, add the following to
`features/support/env.rb`:

```ruby
require "rspec/wait"

World(RSpec::Wait)
```

## Who wrote RSpec::Wait?

My name is Steve Richert and I wrote RSpec::Wait in April, 2014 with the support
of my employer, [Collective Idea](http://www.collectiveidea.com). RSpec::Wait
owes its current and future success entirely to [inspiration](https://github.com/laserlemon/rspec-wait/issues)
and [contribution](https://github.com/laserlemon/rspec-wait/graphs/contributors)
from the Ruby community, especially the [authors and maintainers](https://github.com/rspec/rspec-core/graphs/contributors)
of RSpec.

**Thank you!** :yellow_heart:

## How can I help?

RSpec::Wait is open source and contributions from the community are encouraged!
No contribution is too small.

See RSpec::Wait's [contribution guidelines](CONTRIBUTING.md) for more
information.

If you're enjoying RSpec::Wait, please consider [sponsoring](https://github.com/sponsors/laserlemon)
my [open source work](https://github.com/laserlemon)! :green_heart:

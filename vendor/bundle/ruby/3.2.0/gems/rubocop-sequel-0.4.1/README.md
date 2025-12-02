![CI status](https://github.com/rubocop/rubocop-sequel/workflows/CI/badge.svg)

# RuboCop Sequel

Code style checking for [Sequel](https://sequel.jeremyevans.net/).

## Installation

Using the `rubocop-sequel` gem

```bash
gem install rubocop-sequel
```

or using bundler by adding in your `Gemfile`

```
gem 'rubocop-sequel'
```

## Usage

### RuboCop configuration file

Add to your `.rubocop.yml`.

```
plugins: rubocop-sequel
```

`rubocop` will now automatically load RuboCop Sequel
cops alongside with the standard cops.

> [!NOTE]
> The plugin system is supported in RuboCop 1.72+. In earlier versions, use `require` instead of `plugins`.

### Command line

```bash
rubocop --plugin rubocop-sequel
```

### Rake task

```ruby
RuboCop::RakeTask.new do |task|
  task.plugins << 'rubocop-sequel'
end
```

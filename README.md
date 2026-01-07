# bundler-ignore-dependency

A Bundler plugin that allows you to ignore version constraints on Ruby, RubyGems, or gem dependencies during resolution.

## Installation

Add to your Gemfile:

```ruby
plugin "bundler-ignore-dependency"
```

Or install directly:

```bash
bundler plugin install bundler-ignore-dependency
```

## Usage

The plugin adds an `ignore_dependency!` method to your Gemfile DSL.

### Basic Syntax

```ruby
ignore_dependency! :ruby                      # Ignore Ruby version completely
ignore_dependency! :ruby, type: :upper        # Ignore only upper bounds on Ruby version
ignore_dependency! :rubygems                  # Ignore RubyGems version completely
ignore_dependency! :rubygems, type: :upper    # Ignore only upper bounds on RubyGems version
ignore_dependency! "gem_name"                 # Ignore gem dependency completely
ignore_dependency! "gem_name", type: :upper   # Ignore only upper bounds on gem dependency
```

### Options

- `type: :complete` (default) - Completely ignore the dependency constraint
- `type: :upper` - Only ignore upper bound constraints (`<`, `<=`), keeping lower bounds (`>=`, `>`, `=`)

## Examples

### Ignoring Ruby Version Upper Bounds

You are upgrading to Ruby 4.0 but a gem specifies `required_ruby_version = ">= 3.2", "< 4.0"`:

```ruby
# Gemfile
source "https://rubygems.org"

plugin "bundler-ignore-dependency"
ignore_dependency! :ruby, type: :upper

gem "legacy_gem"  # Works even if it claims to only support Ruby < 4.0
```

This keeps the lower bound (`>= 3.2`) but ignores the upper bound (`< 3.0`). The gem could still have compatibility problems with Ruby 4.0 when installed this way, but you can at least run your test suite to see if it works or not.

### Completely Ignoring Ruby Version

For testing purposes, you might want to completely ignore Ruby version constraints:

```ruby
# Gemfile
source "https://rubygems.org"

plugin "bundler-ignore-dependency"
ignore_dependency! :ruby

gem "future_gem"  # Works even if it requires Ruby >= 99.0
```

### Ignoring RubyGems Version Constraints

```ruby
# Gemfile
source "https://rubygems.org"

plugin "bundler-ignore-dependency"
ignore_dependency! :rubygems, type: :upper

gem "some_gem"
```

### Ignoring Gem Dependency Upper Bounds

If a gem has an overly restrictive dependency on another gem:

```ruby
# Gemfile
source "https://rubygems.org"

plugin "bundler-ignore-dependency"
ignore_dependency! "nokogiri", type: :upper

gem "some_gem"  # Even if it requires nokogiri < 1.14, newer versions will be allowed
```

### Using a Fork With a Different Gem Name

If you have a fork of a gem published under a different name, you can ignore the original dependency and use your fork instead:

```ruby
# Gemfile
source "https://rubygems.org"

plugin "bundler-ignore-dependency"
ignore_dependency! "redis"

gem "redis-mycompany"  # Your fork, published under a different name
gem "sidekiq"          # Depends on "redis", but we're using our fork instead
```

This removes `redis` from dependency resolution entirely, allowing `redis-mycompany` to satisfy the runtime requirements (assuming it provides the same `require` path and API).

### Multiple Ignore Rules

You can combine multiple ignore rules:

```ruby
# Gemfile
source "https://rubygems.org"

plugin "bundler-ignore-dependency"
ignore_dependency! :ruby, type: :upper
ignore_dependency! :rubygems, type: :upper
ignore_dependency! "nokogiri"

gem "rails"
gem "legacy_gem"
```

## When to Use This Plugin

This plugin is useful when:

- You're running a newer Ruby version than a gem officially supports, but the gem works fine
- You need to test compatibility with newer Ruby/RubyGems versions before gems update their constraints
- A gem has overly conservative version constraints that prevent resolution
- You're doing development/testing and need to bypass version checks temporarily

## Caveats

- Use this plugin carefully - version constraints exist for a reason
- Ignoring constraints may lead to runtime errors if there are actual incompatibilities
- Consider reporting overly restrictive constraints to gem maintainers
- This is primarily intended for development, testing, and working around temporary issues

## Acknowledgments

Thanks to [John Hawthorn](https://github.com/jhawthorn) for the original idea to ignore dependencies completely, not just upper bounds.

## License

MIT

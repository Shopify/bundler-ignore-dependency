# Working with bundler-ignore-dependency

This document provides guidance for LLMs and developers working on this project.

## Project Overview

`bundler-ignore-dependency` is a Bundler plugin that allows developers to ignore version constraints on Ruby, RubyGems, or gem dependencies. This is useful in monorepo scenarios where you want to test gems against specific versions without strict version constraints.

## Development Workflow

### Running Tests

```bash
# Run all tests
bin/minitest

# Run unit tests only
bin/minitest test/unit

# Run CLI tests only
bin/minitest test/cli

# Run a specific test file
bin/minitest test/cli/ignore_dependency_test.rb
```

### Code Linting

```bash
# Check code style
bin/rubocop

# Auto-correct style violations
bin/rubocop -a
```

### CI/CD

The GitHub Actions workflow (`.github/workflows/ci.yml`) automatically:
- Fetches the latest 2 major Bundler versions dynamically
- Tests against Ruby 3.3, 3.4, and 4.0
- Runs RuboCop linting
- Runs all 86 tests

## Key Architecture

### Patch System

The plugin works by monkey-patching Bundler classes to intercept dependency resolution:

1. **DefinitionPatch** - Stores ignored dependencies list
2. **DSLPatch** - Provides `ignore_dependency!` DSL method
3. **ResolverPatch** - Filters out ignored dependencies during resolution
4. **MatchMetadataPatch** - Handles version requirement manipulation
5. **LazySpecificationPatch** - Prevents ignored gems from being locked
6. **SharedHelpersPatch** - Validates DSL arguments
7. **MaterializationPatch** - Prevents fetching of ignored gems

### Test Structure

- `test/unit/` - Unit tests for each patch class and the main module
- `test/cli/` - Integration tests that test the full workflow with Bundler

## Important Notes for LLMs

### When Making Changes

1. **Always run the full test suite** - Use `bin/minitest` to ensure nothing breaks
2. **Check code style** - Run `bin/rubocop -a` to auto-correct style issues
3. **Update documentation** - If changing behavior, update relevant docs
4. **Follow Shopify Ruby Style Guide** - The project enforces this via RuboCop

### Test Patterns

- Unit tests inherit from `BundlerTest` in `test/unit/test_helper.rb`
- CLI tests inherit from `CliTest` in `test/cli/test_helper.rb`
- Use `write_gemfile()` to set up test Gemfiles
- Use `run_bundle_install()` to install the plugin before testing
- Always create test gems with `create_test_gem()` and `create_git_gem()` helpers

### Plugin Installation in Tests

The plugin **must be installed** before it can be used in a Gemfile:

```ruby
run_bundle_install(dir)  # This installs the plugin first, then runs bundle install
```

NOT:
```ruby
run_bundle(dir, "install")  # This skips plugin installation and will fail
```

## Dependencies

### Runtime
- **bundler** - The gem dependency manager (Bundler 2.7+, 4.0+)
- **ruby** - Ruby 3.1 or later

### Development
- **minitest** - Testing framework
- **rubocop** - Code linter
- **rubocop-shopify** - Shopify's RuboCop configuration
- **rubocop-minitest** - Minitest-specific RuboCop rules

## Useful Commands

```bash
# Bundle setup
bundle install

# Run tests
bin/minitest

# Lint code
bin/rubocop

# Auto-fix linting issues
bin/rubocop -a

# View gem information
bundle info bundler-ignore-dependency

# Run specific test
bin/minitest -n test_name

# Run tests matching a pattern
bin/minitest -n /pattern/
```

## File Structure

```
├── lib/bundler/ignore_dependency/
│   ├── version.rb                      # Version constant
│   ├── definition_patch.rb             # Stores ignored dependencies
│   ├── dsl_patch.rb                    # Provides ignore_dependency! DSL
│   ├── resolver_patch.rb               # Filters dependencies
│   ├── match_metadata_patch.rb         # Handles version matching
│   ├── lazy_specification_patch.rb     # Prevents lockfile inclusion
│   ├── shared_helpers_patch.rb         # Validates DSL
│   └── materialization_patch.rb        # Prevents gem fetching
├── test/
│   ├── unit/                           # Unit tests for patches
│   └── cli/                            # Integration tests
├── .github/workflows/
│   └── ci.yml                          # GitHub Actions CI configuration
├── Gemfile                             # Development dependencies
└── bundler-ignore-dependency.gemspec   # Gem specification
```

## Common Issues

### Plugin Not Loading in Tests
If you see "Undefined local variable or method `ignore_dependency!`", ensure:
1. Using `run_bundle_install(dir)` not `run_bundle(dir, "install")`
2. The plugin path is correctly passed to `bundle plugin install`

### Test Failures with Different Bundler Versions
The CI matrix tests against multiple Bundler versions. If a test fails with specific versions:
1. Run tests locally with that Bundler version
2. Check the GitHub Actions logs for the exact failure
3. Ensure patches handle version-specific behavior

### Linting Issues
Run `bin/rubocop -a` to auto-correct most style issues. For issues that can't be auto-corrected:
1. Check the Shopify Ruby Style Guide
2. Review the specific RuboCop rule documentation
3. Consider if an exception is needed (rare, requires RuboCop comment)

## References

- [Shopify Ruby Style Guide](https://ruby-style-guide.shopify.dev/)
- [Bundler Documentation](https://bundler.io/)
- [RuboCop Documentation](https://docs.rubocop.org/)
- [Minitest Documentation](https://github.com/minitest/minitest)

## Questions or Issues?

If working on this project and encountering issues:
1. Check the test files for examples
2. Review the patch classes to understand the implementation
3. Consult this guide for common patterns and issues
4. Look at recent commits for context on recent changes

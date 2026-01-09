# Contributing to bundler-ignore-dependency

We love receiving pull requests from everyone! Here are some ways you can contribute:

## Reporting Issues

- Check if the issue has already been reported
- Include steps to reproduce the issue
- Include your Ruby and Bundler versions
- Include any relevant error messages or logs

## Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b my-new-feature`)
3. Make your changes
4. Add or update tests as needed
5. Ensure all tests pass (`bin/rake test`)
6. Commit your changes (`git commit -am 'Add new feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/paracycle/bundler-ignore-dependency.git
cd bundler-ignore-dependency

# Install dependencies
bundle install

# Run tests
bin/rake test
```

## Running Tests

```bash
# Run all tests
bin/rake test

# Run unit tests only
bin/rake test TEST=test/unit/*_test.rb

# Run CLI tests only
bin/rake test TEST=test/cli/*_test.rb

# Run a specific test file
bin/rake test TEST=test/cli/ignore_dependency_test.rb
```

## Code Style

- Follow existing code style and conventions
- Use meaningful variable and method names
- Add comments for complex logic
- Keep methods small and focused

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

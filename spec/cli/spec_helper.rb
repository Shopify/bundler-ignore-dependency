# frozen_string_literal: true

require 'bundler'
require 'fileutils'
require 'tmpdir'
require 'open3'

# Simple CLI test helpers that don't depend on bundler's internal test infrastructure
module CLIHelpers
  # Result object for bundler commands
  Result = Struct.new(:stdout, :stderr, :success?, :exitstatus)
  # Path to the bundler-ignore-dependency plugin
  def plugin_path
    File.expand_path('../..', __dir__)
  end

  # Create a temporary directory and yield it
  def with_tmp_dir(&block)
    Dir.mktmpdir('bundler-ignore-dependency-test', &block)
  end

  # Write a Gemfile with the plugin require at the top
  # The plugin must be installed first via run_bundle_install
  def write_gemfile(dir, contents)
    gemfile_path = File.join(dir, 'Gemfile')

    # Load the plugin - this is required because the plugin extends the Gemfile DSL
    plugin_require = 'require File.join(Bundler::Plugin.index.load_paths("bundler-ignore-dependency")[0], "bundler/ignore_dependency") rescue nil'

    full_contents = "#{plugin_require}\n\n#{contents}"
    File.write(gemfile_path, full_contents)
    gemfile_path
  end

  # Run a bundler command in the given directory
  def run_bundle(dir, *args, env: {})
    # Use the Ruby and bundler from our current environment
    cmd = [RbConfig.ruby, '-S', 'bundle', *args]

    # Get a completely clean environment from Bundler, then set our test-specific vars
    result = nil
    Bundler.with_unbundled_env do
      full_env = ENV.to_hash.merge(
        'BUNDLE_GEMFILE' => File.join(dir, 'Gemfile'),
        'BUNDLE_LOCKFILE' => File.join(dir, 'Gemfile.lock'),
        # Ensure we don't pick up any local bundle config
        'BUNDLE_APP_CONFIG' => File.join(dir, '.bundle')
      ).merge(env)

      stdout, stderr, status = Open3.capture3(full_env, *cmd, chdir: dir)

      result = Result.new(
        stdout,
        stderr,
        status.success?,
        status.exitstatus
      )
    end
    result
  end

  # Run bundle install, handling the two-step process: install plugin, then install gems
  def run_bundle_install(dir, env: {})
    # Step 1: Install the plugin explicitly using bundle plugin install
    run_bundle(dir, 'plugin', 'install', 'bundler-ignore-dependency', "--path=#{plugin_path}", env: env)

    # Step 2: Now run bundle install with the plugin active
    # Use --jobs=1 to avoid deadlock issues in Bundler 4.0.3's parallel installer
    run_bundle(dir, 'install', '--jobs=1', env: env)
  end

  # Check if a gem is in the lockfile
  def lockfile_includes_gem?(dir, gem_name)
    lockfile = File.join(dir, 'Gemfile.lock')
    return false unless File.exist?(lockfile)

    File.read(lockfile).include?(gem_name)
  end

  # Read the lockfile content
  def read_lockfile(dir)
    lockfile = File.join(dir, 'Gemfile.lock')
    return nil unless File.exist?(lockfile)

    File.read(lockfile)
  end
end

RSpec.configure do |config|
  config.include CLIHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end

# frozen_string_literal: true

require_relative '../test_helper'
require 'bundler'
require 'fileutils'
require 'tmpdir'
require 'open3'

class CliTest < Minitest::Test
  private

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

  # Helper to create a test gem directory structure
  def create_test_gem(dir, name:, version: '1.0.0', dependencies: [], required_ruby_version: nil,
                      required_rubygems_version: nil, subdir: 'gems')
    gem_dir = File.join(dir, subdir, name)
    FileUtils.mkdir_p(File.join(gem_dir, 'lib'))

    # Create lib file
    File.write(File.join(gem_dir, 'lib', "#{name}.rb"),
               "module #{name.split('_').map(&:capitalize).join}; VERSION = '#{version}'; end")

    # Format ruby version requirement (can be string or array)
    ruby_version_line = if required_ruby_version.is_a?(Array)
                          "s.required_ruby_version = #{required_ruby_version.inspect}"
                        elsif required_ruby_version
                          "s.required_ruby_version = '#{required_ruby_version}'"
                        else
                          ''
                        end

    # Create gemspec
    gemspec_content = <<~GEMSPEC
      Gem::Specification.new do |s|
        s.name        = "#{name}"
        s.version     = "#{version}"
        s.platform    = Gem::Platform::RUBY
        s.summary     = "Test gem #{name}"
        s.description = "A test gem for testing"
        s.authors     = ["Test"]
        s.email       = "test@example.com"
        s.files       = ["lib/#{name}.rb"]
        s.homepage    = "https://example.com"
        s.license     = "MIT"
        #{ruby_version_line}
        #{required_rubygems_version ? "s.required_rubygems_version = '#{required_rubygems_version}'" : ''}
        #{dependencies.map { |d| "s.add_dependency '#{d[:name]}', '#{d[:version] || '>= 0'}'" }.join("\n        ")}
      end
    GEMSPEC

    File.write(File.join(gem_dir, "#{name}.gemspec"), gemspec_content)
    gem_dir
  end

  # Helper to create a git repo from a gem directory
  def create_git_gem(dir, name:, version: '1.0.0', dependencies: [])
    gem_dir = create_test_gem(dir, name: name, version: version, dependencies: dependencies, subdir: 'git_gems')

    # Initialize git repo
    Dir.chdir(gem_dir) do
      system('git init -q', exception: true)
      system('git config user.email "test@example.com"', exception: true)
      system('git config user.name "Test"', exception: true)
      system('git add -A', exception: true)
      system('git commit -q --no-gpg-sign -m "Initial commit"', exception: true)
    end

    gem_dir
  end
end

# frozen_string_literal: true

require_relative 'spec_helper'

class TestBundlerIgnoreDependencyPlugin < Minitest::Test
  include CLIHelpers

  # Helper to create a simple gem directory
  # required_ruby_version can be a single constraint string (e.g., "< 2.0") or an array (e.g., [">= 2.5", "< 3.0"])
  def create_test_gem(dir, name:, version: '1.0.0', dependencies: [], required_ruby_version: nil,
                      required_rubygems_version: nil)
    gem_dir = File.join(dir, 'gems', name)
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
        s.description = "A test gem for black box testing"
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

  def test_plugin_installed_successfully_and_bundle_install_works
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'simple_gem')

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        gem "simple_gem", path: "gems/simple_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")
      assert(lockfile_includes_gem?(dir, 'simple_gem'))
    end
  end

  def test_plugin_available_for_subsequent_bundle_commands
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'simple_gem')

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        gem "simple_gem", path: "gems/simple_gem"
      G

      result1 = run_bundle(dir, 'install')
      assert(result1.success?)

      result2 = run_bundle(dir, 'install')
      assert(result2.success?)
    end
  end

  def test_allows_installation_of_gems_with_incompatible_ruby_version
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'legacy_gem', required_ruby_version: '< 2.0')

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! :ruby
        gem "legacy_gem", path: "gems/legacy_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")
      assert(lockfile_includes_gem?(dir, 'legacy_gem'))
    end
  end

  def test_allows_installation_of_gems_with_upper_bound_ruby_version_constraints
    skip('Test requires Ruby >= 3.0') if RUBY_VERSION < '3.0'

    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'upper_bound_ruby_gem', required_ruby_version: ['>= 2.5', '< 3.0'])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! :ruby, type: :upper
        gem "upper_bound_ruby_gem", path: "gems/upper_bound_ruby_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")
      assert(lockfile_includes_gem?(dir, 'upper_bound_ruby_gem'))
    end
  end

  def test_still_enforces_lower_bound_when_only_upper_bound_ignored
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'future_gem', required_ruby_version: ['>= 99.0', '< 100.0'])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! :ruby, type: :upper
        gem "future_gem", path: "gems/future_gem"
      G

      result = run_bundle_install(dir)

      refute(result.success?)
    end
  end

  def test_installs_gems_without_their_ignored_dependencies
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'main_gem', dependencies: [{ name: 'json', version: '>= 2.0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "json"
        gem "main_gem", path: "gems/main_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'main_gem')
      refute_includes(lockfile, 'json (')
    end
  end

  def test_can_ignore_multiple_gem_dependencies
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'main_gem', dependencies: [
                        { name: 'json', version: '>= 2.0' },
                        { name: 'fileutils', version: '>= 1.0' }
                      ])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "json"
        ignore_dependency! "fileutils"
        gem "main_gem", path: "gems/main_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'main_gem')
      refute_includes(lockfile, 'json (')
      refute_includes(lockfile, 'fileutils (')
    end
  end

  def test_allows_resolving_gems_with_conflicting_upper_bound_constraints
    with_tmp_dir do |dir|
      dep_v1_dir = File.join(dir, 'gems', 'shared_dep_v1')
      FileUtils.mkdir_p(File.join(dep_v1_dir, 'lib'))
      File.write(File.join(dep_v1_dir, 'lib', 'shared_dep.rb'), "module SharedDep; VERSION = '1.0.0'; end")
      File.write(File.join(dep_v1_dir, 'shared_dep.gemspec'), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "shared_dep"
          s.version = "1.0.0"
          s.summary = "Shared dependency v1"
          s.authors = ["Test"]
          s.files = ["lib/shared_dep.rb"]
        end
      GEMSPEC

      dep_v2_dir = File.join(dir, 'gems', 'shared_dep_v2')
      FileUtils.mkdir_p(File.join(dep_v2_dir, 'lib'))
      File.write(File.join(dep_v2_dir, 'lib', 'shared_dep.rb'), "module SharedDep; VERSION = '2.0.0'; end")
      File.write(File.join(dep_v2_dir, 'shared_dep.gemspec'), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "shared_dep"
          s.version = "2.0.0"
          s.summary = "Shared dependency v2"
          s.authors = ["Test"]
          s.files = ["lib/shared_dep.rb"]
        end
      GEMSPEC

      create_test_gem(dir, name: 'gem_a', dependencies: [{ name: 'shared_dep', version: '~> 1.0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "shared_dep", type: :upper
        gem "gem_a", path: "gems/gem_a"
        gem "shared_dep", "2.0.0", path: "gems/shared_dep_v2"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'gem_a')
      assert_includes(lockfile, 'shared_dep (2.0.0)')
    end
  end

  def test_can_ignore_both_ruby_and_gem_dependencies
    with_tmp_dir do |dir|
      create_test_gem(dir,
                      name: 'complex_gem',
                      required_ruby_version: '< 2.0',
                      dependencies: [{ name: 'json', version: '>= 1.0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! :ruby
        ignore_dependency! "json"
        gem "complex_gem", path: "gems/complex_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'complex_gem')
      refute_includes(lockfile, 'json (')
    end
  end

  def test_raises_error_for_invalid_ignore_type
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'simple_gem')

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! :ruby, type: :invalid_type
        gem "simple_gem", path: "gems/simple_gem"
      G

      result = run_bundle_install(dir)

      refute(result.success?)
      assert_includes(result.stderr, 'type must be :complete or :upper')
    end
  end

  def test_raises_error_for_invalid_dependency_name
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'simple_gem')

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! 123
        gem "simple_gem", path: "gems/simple_gem"
      G

      result = run_bundle_install(dir)

      refute(result.success?)
      assert_includes(result.stderr, 'dependency name must be :ruby, :rubygems, or a gem name string')
    end
  end

  def test_generates_lockfile_with_ignored_dependencies_filtered_out
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'dep_gem')
      create_test_gem(dir, name: 'main_gem', dependencies: [{ name: 'dep_gem', version: '= 1.0.0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "dep_gem"
        gem "main_gem", path: "gems/main_gem"
      G

      run_bundle(dir, 'install')

      lockfile_path = File.join(dir, 'Gemfile.lock')
      File.delete(lockfile_path) if File.exist?(lockfile_path)

      result = run_bundle(dir, 'lock')

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'main_gem')
      refute_includes(lockfile, 'dep_gem (')
    end
  end
end

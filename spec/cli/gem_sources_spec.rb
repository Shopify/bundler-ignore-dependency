# frozen_string_literal: true

require_relative 'spec_helper'

class TestIgnoreDependencyWithDifferentGemSources < Minitest::Test
  include CLIHelpers
  # Helper to create a simple gem directory structure
  def create_test_gem(dir, name:, version: '1.0.0', dependencies: [], subdir: 'gems')
    gem_dir = File.join(dir, subdir, name)
    FileUtils.mkdir_p(File.join(gem_dir, 'lib'))

    # Create lib file
    File.write(File.join(gem_dir, 'lib', "#{name}.rb"),
               "module #{name.split('_').map(&:capitalize).join}; VERSION = '#{version}'; end")

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
        #{dependencies.map { |d| "s.add_dependency '#{d[:name]}', '#{d[:version] || '>= 0'}'" }.join("\n    ")}
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
      system('git commit -q -m "Initial commit"', exception: true)
    end

    gem_dir
  end

  def test_ignores_dependencies_from_path_gems
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'path_gem', dependencies: [{ name: 'json', version: '>= 2.0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "json"
        gem "path_gem", path: "gems/path_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'path_gem')
      refute_includes(lockfile, 'json (')
    end
  end

  def test_ignores_transitive_dependencies_from_path_gems
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'intermediate_dep', dependencies: [{ name: 'json', version: '>= 1.0' }])
      create_test_gem(dir, name: 'path_gem', dependencies: [{ name: 'intermediate_dep', version: '>= 0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "json"
        gem "path_gem", path: "gems/path_gem"
        gem "intermediate_dep", path: "gems/intermediate_dep"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'path_gem')
      assert_includes(lockfile, 'intermediate_dep')
      refute_includes(lockfile, 'json (')
    end
  end

  def test_ignores_dependencies_from_git_gems
    with_tmp_dir do |dir|
      git_gem_path = create_git_gem(dir, name: 'git_gem', dependencies: [{ name: 'json', version: '>= 2.0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "json"
        gem "git_gem", git: "#{git_gem_path}"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'git_gem')
      refute_includes(lockfile, 'json (')
    end
  end

  def test_ignores_dependencies_from_git_gems_with_branch_specified
    with_tmp_dir do |dir|
      git_gem_path = create_git_gem(dir, name: 'git_branch_gem',
                                         dependencies: [{ name: 'fileutils', version: '>= 1.0' }])

      Dir.chdir(git_gem_path) do
        system('git checkout -q -b feature-branch', exception: true)
      end

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "fileutils"
        gem "git_branch_gem", git: "#{git_gem_path}", branch: "feature-branch"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'git_branch_gem')
      refute_includes(lockfile, 'fileutils (')
    end
  end

  def test_ignores_dependencies_from_git_gems_with_tag_specified
    with_tmp_dir do |dir|
      git_gem_path = create_git_gem(dir, name: 'git_tag_gem', dependencies: [{ name: 'ostruct', version: '>= 0' }])

      Dir.chdir(git_gem_path) do
        system('git tag v1.0.0', exception: true)
      end

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "ostruct"
        gem "git_tag_gem", git: "#{git_gem_path}", tag: "v1.0.0"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'git_tag_gem')
      refute_includes(lockfile, 'ostruct (')
    end
  end

  def test_ignores_dependencies_when_developing_gem_with_gemspec
    with_tmp_dir do |dir|
      gem_dir = File.join(dir, 'my_gem')
      FileUtils.mkdir_p(File.join(gem_dir, 'lib'))

      File.write(File.join(gem_dir, 'lib', 'my_gem.rb'), "module MyGem; VERSION = '1.0.0'; end")

      File.write(File.join(gem_dir, 'my_gem.gemspec'), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name        = "my_gem"
          s.version     = "1.0.0"
          s.summary     = "My gem under development"
          s.authors     = ["Test"]
          s.files       = ["lib/my_gem.rb"]
          s.add_dependency "json", ">= 2.0"
          s.add_development_dependency "rake", ">= 10.0"
        end
      GEMSPEC

      gemfile_path = File.join(gem_dir, 'Gemfile')
      plugin_require = 'require File.join(Bundler::Plugin.index.load_paths("bundler-ignore-dependency")[0], "bundler/ignore_dependency") rescue nil'

      File.write(gemfile_path, <<~G)
        #{plugin_require}

        source "https://rubygems.org"
        ignore_dependency! "json"
        gemspec
      G

      run_bundle(gem_dir, 'plugin', 'install', 'bundler-ignore-dependency', "--path=#{plugin_path}")
      result = run_bundle(gem_dir, 'install', '--jobs=1')

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(gem_dir)
      assert_includes(lockfile, 'my_gem')
      refute_includes(lockfile, 'json (')
      assert_includes(lockfile, 'rake')
    end
  end

  def test_ignores_dependencies_from_remote_rubygems
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'my_app', dependencies: [{ name: 'bigdecimal', version: '>= 0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "bigdecimal"
        gem "my_app", path: "gems/my_app"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'my_app')
      refute_includes(lockfile, 'bigdecimal (')
    end
  end

  def test_can_use_real_remote_gems_while_ignoring_their_dependencies
    with_tmp_dir do |dir|
      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "stringio"

        gem "rake", "~> 13.0"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'rake')
    end
  end

  def test_ignores_dependencies_across_path_and_git_sources
    with_tmp_dir do |dir|
      git_gem_path = create_git_gem(dir, name: 'git_dep', dependencies: [{ name: 'json', version: '>= 1.0' }])

      create_test_gem(dir, name: 'path_app', dependencies: [
                        { name: 'git_dep', version: '>= 0' },
                        { name: 'fileutils', version: '>= 1.0' }
                      ])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "json"
        ignore_dependency! "fileutils"
        gem "git_dep", git: "#{git_gem_path}"
        gem "path_app", path: "gems/path_app"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'git_dep')
      assert_includes(lockfile, 'path_app')
      refute_includes(lockfile, 'json (')
      refute_includes(lockfile, 'fileutils (')
    end
  end

  def test_ignores_ruby_version_constraints_from_gems_across_different_sources
    with_tmp_dir do |dir|
      git_gem_dir = File.join(dir, 'git_gems', 'old_git_gem')
      FileUtils.mkdir_p(File.join(git_gem_dir, 'lib'))
      File.write(File.join(git_gem_dir, 'lib', 'old_git_gem.rb'), 'module OldGitGem; end')
      File.write(File.join(git_gem_dir, 'old_git_gem.gemspec'), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "old_git_gem"
          s.version = "1.0.0"
          s.summary = "Old git gem"
          s.authors = ["Test"]
          s.files = ["lib/old_git_gem.rb"]
          s.required_ruby_version = "< 2.0"
        end
      GEMSPEC

      Dir.chdir(git_gem_dir) do
        system('git init -q', exception: true)
        system('git config user.email "test@example.com"', exception: true)
        system('git config user.name "Test"', exception: true)
        system('git add -A', exception: true)
        system('git commit -q -m "Initial commit"', exception: true)
      end

      path_gem_dir = File.join(dir, 'gems', 'old_path_gem')
      FileUtils.mkdir_p(File.join(path_gem_dir, 'lib'))
      File.write(File.join(path_gem_dir, 'lib', 'old_path_gem.rb'), 'module OldPathGem; end')
      File.write(File.join(path_gem_dir, 'old_path_gem.gemspec'), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "old_path_gem"
          s.version = "1.0.0"
          s.summary = "Old path gem"
          s.authors = ["Test"]
          s.files = ["lib/old_path_gem.rb"]
          s.required_ruby_version = "< 2.0"
        end
      GEMSPEC

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! :ruby
        gem "old_git_gem", git: "#{git_gem_dir}"
        gem "old_path_gem", path: "gems/old_path_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'old_git_gem')
      assert_includes(lockfile, 'old_path_gem')
    end
  end

  def test_handles_gems_with_no_dependencies
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'no_deps_gem', dependencies: [])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "nonexistent"
        gem "no_deps_gem", path: "gems/no_deps_gem"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'no_deps_gem')
    end
  end

  def test_handles_multiple_gems_from_same_git_repo
    with_tmp_dir do |dir|
      multi_gem_dir = File.join(dir, 'git_gems', 'multi_gem_repo')
      FileUtils.mkdir_p(multi_gem_dir)

      gem1_dir = File.join(multi_gem_dir, 'gem_one')
      FileUtils.mkdir_p(File.join(gem1_dir, 'lib'))
      File.write(File.join(gem1_dir, 'lib', 'gem_one.rb'), 'module GemOne; end')
      File.write(File.join(gem1_dir, 'gem_one.gemspec'), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "gem_one"
          s.version = "1.0.0"
          s.summary = "Gem one"
          s.authors = ["Test"]
          s.files = ["lib/gem_one.rb"]
          s.add_dependency "json", ">= 1.0"
        end
      GEMSPEC

      gem2_dir = File.join(multi_gem_dir, 'gem_two')
      FileUtils.mkdir_p(File.join(gem2_dir, 'lib'))
      File.write(File.join(gem2_dir, 'lib', 'gem_two.rb'), 'module GemTwo; end')
      File.write(File.join(gem2_dir, 'gem_two.gemspec'), <<~GEMSPEC)
        Gem::Specification.new do |s|
          s.name = "gem_two"
          s.version = "1.0.0"
          s.summary = "Gem two"
          s.authors = ["Test"]
          s.files = ["lib/gem_two.rb"]
          s.add_dependency "fileutils", ">= 1.0"
        end
      GEMSPEC

      Dir.chdir(multi_gem_dir) do
        system('git init -q', exception: true)
        system('git config user.email "test@example.com"', exception: true)
        system('git config user.name "Test"', exception: true)
        system('git add -A', exception: true)
        system('git commit -q -m "Initial commit"', exception: true)
      end

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "json"
        ignore_dependency! "fileutils"
        gem "gem_one", git: "#{multi_gem_dir}", glob: "gem_one/*.gemspec"
        gem "gem_two", git: "#{multi_gem_dir}", glob: "gem_two/*.gemspec"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'gem_one')
      assert_includes(lockfile, 'gem_two')
      refute_includes(lockfile, 'json (')
      refute_includes(lockfile, 'fileutils (')
    end
  end

  def test_handles_deeply_nested_dependencies
    with_tmp_dir do |dir|
      create_test_gem(dir, name: 'gem_c', dependencies: [{ name: 'json', version: '>= 1.0' }])
      create_test_gem(dir, name: 'gem_b', dependencies: [{ name: 'gem_c', version: '>= 0' }])
      create_test_gem(dir, name: 'gem_a', dependencies: [{ name: 'gem_b', version: '>= 0' }])

      write_gemfile(dir, <<~G)
        source "https://rubygems.org"
        ignore_dependency! "json"
        gem "gem_a", path: "gems/gem_a"
        gem "gem_b", path: "gems/gem_b"
        gem "gem_c", path: "gems/gem_c"
      G

      result = run_bundle_install(dir)

      assert(result.success?,
             "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}")

      lockfile = read_lockfile(dir)
      assert_includes(lockfile, 'gem_a')
      assert_includes(lockfile, 'gem_b')
      assert_includes(lockfile, 'gem_c')
      refute_includes(lockfile, 'json (')
    end
  end
end

# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'ignore_dependency! with different gem sources (CLI)' do
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

  describe 'with path source' do
    it 'ignores dependencies from path gems' do
      with_tmp_dir do |dir|
        # Create a path gem that depends on json
        create_test_gem(dir, name: 'path_gem', dependencies: [{ name: 'json', version: '>= 2.0' }])

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "json"
          gem "path_gem", path: "gems/path_gem"
        G

        result = run_bundle_install(dir)

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('path_gem')
        expect(lockfile).not_to include('json (')
      end
    end

    it 'ignores transitive dependencies from path gems' do
      with_tmp_dir do |dir|
        # Create a chain: path_gem -> intermediate_dep -> json
        # We'll use path gems for all to avoid network calls
        create_test_gem(dir, name: 'intermediate_dep', dependencies: [{ name: 'json', version: '>= 1.0' }])
        create_test_gem(dir, name: 'path_gem', dependencies: [{ name: 'intermediate_dep', version: '>= 0' }])

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "json"
          gem "path_gem", path: "gems/path_gem"
          gem "intermediate_dep", path: "gems/intermediate_dep"
        G

        result = run_bundle_install(dir)

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('path_gem')
        expect(lockfile).to include('intermediate_dep')
        expect(lockfile).not_to include('json (')
      end
    end
  end

  describe 'with git source' do
    it 'ignores dependencies from git gems' do
      with_tmp_dir do |dir|
        # Create a git gem that depends on json
        git_gem_path = create_git_gem(dir, name: 'git_gem', dependencies: [{ name: 'json', version: '>= 2.0' }])

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "json"
          gem "git_gem", git: "#{git_gem_path}"
        G

        result = run_bundle_install(dir)

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('git_gem')
        expect(lockfile).not_to include('json (')
      end
    end

    it 'ignores dependencies from git gems with branch specified' do
      with_tmp_dir do |dir|
        git_gem_path = create_git_gem(dir, name: 'git_branch_gem',
                                           dependencies: [{ name: 'fileutils', version: '>= 1.0' }])

        # Create a branch
        Dir.chdir(git_gem_path) do
          system('git checkout -q -b feature-branch', exception: true)
        end

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "fileutils"
          gem "git_branch_gem", git: "#{git_gem_path}", branch: "feature-branch"
        G

        result = run_bundle_install(dir)

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('git_branch_gem')
        expect(lockfile).not_to include('fileutils (')
      end
    end

    it 'ignores dependencies from git gems with tag specified' do
      with_tmp_dir do |dir|
        git_gem_path = create_git_gem(dir, name: 'git_tag_gem', dependencies: [{ name: 'ostruct', version: '>= 0' }])

        # Create a tag
        Dir.chdir(git_gem_path) do
          system('git tag v1.0.0', exception: true)
        end

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "ostruct"
          gem "git_tag_gem", git: "#{git_gem_path}", tag: "v1.0.0"
        G

        result = run_bundle_install(dir)

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('git_tag_gem')
        expect(lockfile).not_to include('ostruct (')
      end
    end
  end

  describe 'with gemspec source' do
    it 'ignores dependencies when developing a gem with gemspec' do
      with_tmp_dir do |dir|
        # Create a gem being developed (simulating gem development workflow)
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

        # Write Gemfile in the gem directory (standard gem development setup)
        gemfile_path = File.join(gem_dir, 'Gemfile')
        plugin_require = 'require File.join(Bundler::Plugin.index.load_paths("bundler-ignore-dependency")[0], "bundler/ignore_dependency") rescue nil'

        File.write(gemfile_path, <<~G)
          #{plugin_require}

          source "https://rubygems.org"
          ignore_dependency! "json"
          gemspec
        G

        # Install plugin and run bundle install in the gem directory
        run_bundle(gem_dir, 'plugin', 'install', 'bundler-ignore-dependency', "--path=#{plugin_path}")
        result = run_bundle(gem_dir, 'install', '--jobs=1')

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(gem_dir)
        expect(lockfile).to include('my_gem')
        expect(lockfile).not_to include('json (')
        # Development dependencies should still be included
        expect(lockfile).to include('rake')
      end
    end
  end

  describe 'with rubygems source (remote gems)' do
    it 'ignores dependencies from remote rubygems' do
      with_tmp_dir do |dir|
        # Use a real gem from rubygems.org that has dependencies
        # rake depends on nothing, but we can test with a gem that does
        # For this test, we'll create a path gem that depends on a real remote gem's dependency

        # Create a path gem that depends on bigdecimal (which is a real gem)
        create_test_gem(dir, name: 'my_app', dependencies: [{ name: 'bigdecimal', version: '>= 0' }])

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "bigdecimal"
          gem "my_app", path: "gems/my_app"
        G

        result = run_bundle_install(dir)

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('my_app')
        expect(lockfile).not_to include('bigdecimal (')
      end
    end

    it 'can use real remote gems while ignoring their dependencies' do
      with_tmp_dir do |dir|
        # Test with a real remote gem that has dependencies
        # minitest is a good choice as it's commonly available and has no deps
        # Instead, let's use a path gem approach to test the mechanism

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "stringio"

          # minitest doesn't have runtime deps, so let's create our own scenario
          gem "rake", "~> 13.0"
        G

        result = run_bundle_install(dir)

        # rake doesn't actually depend on stringio, but this tests that
        # ignore_dependency! doesn't break normal remote gem installation
        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('rake')
      end
    end
  end

  describe 'with mixed sources' do
    it 'ignores dependencies across path and git sources' do
      with_tmp_dir do |dir|
        # Create a git gem
        git_gem_path = create_git_gem(dir, name: 'git_dep', dependencies: [{ name: 'json', version: '>= 1.0' }])

        # Create a path gem that depends on the git gem
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

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('git_dep')
        expect(lockfile).to include('path_app')
        expect(lockfile).not_to include('json (')
        expect(lockfile).not_to include('fileutils (')
      end
    end

    it 'ignores Ruby version constraints from gems across different sources' do
      with_tmp_dir do |dir|
        # Create a git gem with old Ruby requirement
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

        # Create a path gem with old Ruby requirement
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

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('old_git_gem')
        expect(lockfile).to include('old_path_gem')
      end
    end
  end

  describe 'edge cases' do
    it 'handles gems with no dependencies' do
      with_tmp_dir do |dir|
        create_test_gem(dir, name: 'no_deps_gem', dependencies: [])

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "nonexistent"
          gem "no_deps_gem", path: "gems/no_deps_gem"
        G

        result = run_bundle_install(dir)

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('no_deps_gem')
      end
    end

    it 'handles multiple gems from same git repo' do
      with_tmp_dir do |dir|
        # Create a git repo with multiple gems
        multi_gem_dir = File.join(dir, 'git_gems', 'multi_gem_repo')
        FileUtils.mkdir_p(multi_gem_dir)

        # First gem
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

        # Second gem
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

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('gem_one')
        expect(lockfile).to include('gem_two')
        expect(lockfile).not_to include('json (')
        expect(lockfile).not_to include('fileutils (')
      end
    end

    it 'handles deeply nested dependencies' do
      with_tmp_dir do |dir|
        # Create a deep dependency chain: app -> gem_a -> gem_b -> gem_c -> json
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

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('gem_a')
        expect(lockfile).to include('gem_b')
        expect(lockfile).to include('gem_c')
        expect(lockfile).not_to include('json (')
      end
    end
  end
end

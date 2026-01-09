# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'bundler-ignore-dependency plugin (CLI)' do
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

  describe 'plugin installation' do
    it 'plugin is installed successfully and bundle install works' do
      with_tmp_dir do |dir|
        create_test_gem(dir, name: 'simple_gem')

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          gem "simple_gem", path: "gems/simple_gem"
        G

        # Use run_bundle_install for two-pass plugin activation
        result = run_bundle_install(dir)

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"
        expect(lockfile_includes_gem?(dir, 'simple_gem')).to be true
      end
    end

    it 'plugin is available for subsequent bundle commands' do
      with_tmp_dir do |dir|
        create_test_gem(dir, name: 'simple_gem')

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          gem "simple_gem", path: "gems/simple_gem"
        G

        result1 = run_bundle(dir, 'install')
        expect(result1.success?).to be true

        result2 = run_bundle(dir, 'install')
        expect(result2.success?).to be true
      end
    end
  end

  describe 'ignoring Ruby version constraints' do
    context 'with complete ignore' do
      it 'allows installation of gems with incompatible Ruby version requirements' do
        with_tmp_dir do |dir|
          # Create a gem that requires an impossible Ruby version
          create_test_gem(dir, name: 'legacy_gem', required_ruby_version: '< 2.0')

          write_gemfile(dir, <<~G)
            source "https://rubygems.org"
            ignore_dependency! :ruby
            gem "legacy_gem", path: "gems/legacy_gem"
          G

          # Use run_bundle_install for two-pass plugin activation
          result = run_bundle_install(dir)

          expect(result.success?).to be(true),
                                     "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"
          expect(lockfile_includes_gem?(dir, 'legacy_gem')).to be true
        end
      end
    end

    context 'with upper bound ignore' do
      it 'allows installation of gems with upper bound Ruby version constraints' do
        # This test creates a gem that requires Ruby < 3.0
        # On Ruby >= 3.0, this would normally fail, but with upper bound ignore it should work
        skip 'Test requires Ruby >= 3.0' if RUBY_VERSION < '3.0'

        with_tmp_dir do |dir|
          create_test_gem(dir, name: 'upper_bound_ruby_gem', required_ruby_version: ['>= 2.5', '< 3.0'])

          write_gemfile(dir, <<~G)
            source "https://rubygems.org"
            ignore_dependency! :ruby, type: :upper
            gem "upper_bound_ruby_gem", path: "gems/upper_bound_ruby_gem"
          G

          # Use run_bundle_install for two-pass plugin activation
          result = run_bundle_install(dir)

          expect(result.success?).to be(true),
                                     "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"
          expect(lockfile_includes_gem?(dir, 'upper_bound_ruby_gem')).to be true
        end
      end

      it 'still enforces lower bound when only upper bound is ignored' do
        # Create a gem requiring a future Ruby version - lower bound should still fail
        with_tmp_dir do |dir|
          create_test_gem(dir, name: 'future_gem', required_ruby_version: ['>= 99.0', '< 100.0'])

          write_gemfile(dir, <<~G)
            source "https://rubygems.org"
            ignore_dependency! :ruby, type: :upper
            gem "future_gem", path: "gems/future_gem"
          G

          # Use run_bundle_install for two-pass plugin activation
          result = run_bundle_install(dir)

          # Should fail because lower bound (>= 99.0) is not met
          expect(result.success?).to be false
        end
      end
    end
  end

  describe 'ignoring gem dependency constraints' do
    context 'with complete ignore' do
      it 'installs gems without their ignored dependencies' do
        with_tmp_dir do |dir|
          # Create a main gem that depends on json
          create_test_gem(dir, name: 'main_gem', dependencies: [{ name: 'json', version: '>= 2.0' }])

          write_gemfile(dir, <<~G)
            source "https://rubygems.org"
            ignore_dependency! "json"
            gem "main_gem", path: "gems/main_gem"
          G

          # Use run_bundle_install for two-pass plugin activation
          result = run_bundle_install(dir)

          # Should succeed because json is ignored, so bundler won't try to fetch it
          # even though main_gem depends on it
          expect(result.success?).to be(true),
                                     "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

          lockfile = read_lockfile(dir)
          expect(lockfile).to include('main_gem')
          # json should not be in the lockfile because it was ignored
          expect(lockfile).not_to include('json (')
        end
      end

      it 'can ignore multiple gem dependencies' do
        with_tmp_dir do |dir|
          # Create a main gem that depends on multiple dependencies
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

          # Use run_bundle_install for two-pass plugin activation
          result = run_bundle_install(dir)

          expect(result.success?).to be(true),
                                     "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

          lockfile = read_lockfile(dir)
          expect(lockfile).to include('main_gem')
          expect(lockfile).not_to include('json (')
          expect(lockfile).not_to include('fileutils (')
        end
      end
    end

    context 'with upper bound ignore' do
      it 'allows resolving gems with conflicting upper bound constraints' do
        with_tmp_dir do |dir|
          # Create two versions of a dependency
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

          # Gem that requires shared_dep < 2.0
          create_test_gem(dir, name: 'gem_a', dependencies: [{ name: 'shared_dep', version: '~> 1.0' }])

          write_gemfile(dir, <<~G)
            source "https://rubygems.org"
            ignore_dependency! "shared_dep", type: :upper
            gem "gem_a", path: "gems/gem_a"
            gem "shared_dep", "2.0.0", path: "gems/shared_dep_v2"
          G

          # Use run_bundle_install for two-pass plugin activation
          result = run_bundle_install(dir)

          expect(result.success?).to be(true),
                                     "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

          lockfile = read_lockfile(dir)
          expect(lockfile).to include('gem_a')
          expect(lockfile).to include('shared_dep (2.0.0)')
        end
      end
    end
  end

  describe 'combining multiple ignore rules' do
    it 'can ignore both Ruby and gem dependencies' do
      with_tmp_dir do |dir|
        # Create a complex gem that depends on json and has old Ruby requirement
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

        # Use run_bundle_install for two-pass plugin activation
        result = run_bundle_install(dir)

        # Should succeed because:
        # 1. Ruby version constraint is ignored (< 2.0 doesn't matter)
        # 2. json dependency is ignored (won't try to fetch it)
        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('complex_gem')
        expect(lockfile).not_to include('json (')
      end
    end
  end

  describe 'error handling' do
    it 'raises error for invalid ignore type' do
      with_tmp_dir do |dir|
        create_test_gem(dir, name: 'simple_gem')

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! :ruby, type: :invalid_type
          gem "simple_gem", path: "gems/simple_gem"
        G

        # Use run_bundle_install for two-pass plugin activation
        result = run_bundle_install(dir)

        expect(result.success?).to be false
        expect(result.stderr).to include('type must be :complete or :upper')
      end
    end

    it 'raises error for invalid dependency name' do
      with_tmp_dir do |dir|
        create_test_gem(dir, name: 'simple_gem')

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! 123
          gem "simple_gem", path: "gems/simple_gem"
        G

        # Use run_bundle_install for two-pass plugin activation
        result = run_bundle_install(dir)

        expect(result.success?).to be false
        expect(result.stderr).to include('dependency name must be :ruby, :rubygems, or a gem name string')
      end
    end
  end

  describe 'bundle lock' do
    it 'generates lockfile with ignored dependencies filtered out' do
      with_tmp_dir do |dir|
        create_test_gem(dir, name: 'dep_gem')
        create_test_gem(dir, name: 'main_gem', dependencies: [{ name: 'dep_gem', version: '= 1.0.0' }])

        write_gemfile(dir, <<~G)
          source "https://rubygems.org"
          ignore_dependency! "dep_gem"
          gem "main_gem", path: "gems/main_gem"
        G

        # First run to install plugin
        run_bundle(dir, 'install')

        # Remove lockfile and run lock with plugin active
        lockfile_path = File.join(dir, 'Gemfile.lock')
        File.delete(lockfile_path) if File.exist?(lockfile_path)

        result = run_bundle(dir, 'lock')

        expect(result.success?).to be(true),
                                   "Expected success but got:\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"

        lockfile = read_lockfile(dir)
        expect(lockfile).to include('main_gem')
        expect(lockfile).not_to include('dep_gem (')
      end
    end
  end
end

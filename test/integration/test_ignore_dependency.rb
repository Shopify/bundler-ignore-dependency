# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'tmpdir'

class TestIgnoreDependencyIntegration < Minitest::Test
  def teardown
    # Clean up cache after each test
    Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
  end

  def with_ignored_dependencies(deps)
    original_definition = Bundler.instance_variable_get(:@definition)

    definition = Object.new
    definition.define_singleton_method(:ignored_dependencies) { deps }

    Bundler.instance_variable_set(:@definition, definition)
    begin
      Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
      yield
    ensure
      Bundler.instance_variable_set(:@definition, original_definition)
    end
  end

  def test_can_ignore_ruby_completely_with_normalized_key
    dsl = Bundler::Dsl.new
    dsl.ignore_dependency!(:ruby)

    assert_equal({ "Ruby\0" => :complete }, dsl.instance_variable_get(:@ignored_dependencies))
  end

  def test_can_ignore_ruby_upper_bounds_only_with_normalized_key
    dsl = Bundler::Dsl.new
    dsl.ignore_dependency!(:ruby, type: :upper)

    assert_equal({ "Ruby\0" => :upper }, dsl.instance_variable_get(:@ignored_dependencies))
  end

  def test_can_ignore_multiple_dependencies_with_normalized_keys
    dsl = Bundler::Dsl.new
    dsl.ignore_dependency!(:ruby, type: :upper)
    dsl.ignore_dependency!(:rubygems)
    dsl.ignore_dependency!('nokogiri')

    assert_equal({
                   "Ruby\0" => :upper,
                   "RubyGems\0" => :complete,
                   'nokogiri' => :complete
                 }, dsl.instance_variable_get(:@ignored_dependencies))
  end

  def test_propagates_settings_through_to_definition_with_normalized_keys
    Dir.mktmpdir do |dir|
      gemfile_path = File.join(dir, 'Gemfile')
      lockfile_path = File.join(dir, 'Gemfile.lock')

      File.write(gemfile_path, <<~GEMFILE)
        source "https://rubygems.org"
        ignore_dependency! :ruby, type: :upper
      GEMFILE

      original_method = begin
        Bundler::SharedHelpers.method(:pwd)
      rescue StandardError
        nil
      end

      Bundler::SharedHelpers.define_singleton_method(:pwd) { dir }
      begin
        definition = Bundler::Definition.build(gemfile_path, lockfile_path, {})
        assert_equal({ "Ruby\0" => :upper }, definition.ignored_dependencies)
      ensure
        if original_method
          Bundler::SharedHelpers.define_singleton_method(:pwd, &original_method)
        elsif Bundler::SharedHelpers.respond_to?(:pwd)
          Bundler::SharedHelpers.singleton_class.undef_method(:pwd)
        end
      end
    end
  end

  def test_rejects_gem_when_ruby_not_ignored_on_ruby_3x
    skip('Test requires Ruby >= 3.0') if Gem.ruby_version < Gem::Version.new('3.0.0')

    with_ignored_dependencies({}) do
      spec = Gem::Specification.new do |s|
        s.name = 'test_gem'
        s.version = '1.0.0'
        s.required_ruby_version = ['>= 2.7.0', '< 3.0.0']
      end
      refute(spec.matches_current_ruby?)
    end
  end

  def test_accepts_gem_when_ruby_completely_ignored_on_ruby_3x
    skip('Test requires Ruby >= 3.0') if Gem.ruby_version < Gem::Version.new('3.0.0')

    with_ignored_dependencies({ "Ruby\0" => :complete }) do
      spec = Gem::Specification.new do |s|
        s.name = 'test_gem'
        s.version = '1.0.0'
        s.required_ruby_version = ['>= 2.7.0', '< 3.0.0']
      end
      assert(spec.matches_current_ruby?)
    end
  end

  def test_accepts_gem_when_ruby_upper_bound_ignored_on_ruby_3x
    skip('Test requires Ruby >= 3.0') if Gem.ruby_version < Gem::Version.new('3.0.0')

    with_ignored_dependencies({ "Ruby\0" => :upper }) do
      spec = Gem::Specification.new do |s|
        s.name = 'test_gem'
        s.version = '1.0.0'
        s.required_ruby_version = ['>= 2.7.0', '< 3.0.0']
      end
      assert(spec.matches_current_ruby?)
    end
  end

  def test_allows_legacy_gem_with_upper_bound_ignore
    skip('Test requires Ruby >= 3.0') if Gem.ruby_version < Gem::Version.new('3.0.0')

    legacy_spec = Gem::Specification.new do |s|
      s.name = 'legacy_gem'
      s.version = '2.0.0'
      s.required_ruby_version = ['>= 2.5.0', '< 3.0.0']
    end

    with_ignored_dependencies({}) do
      refute(legacy_spec.matches_current_ruby?)
    end

    with_ignored_dependencies({ "Ruby\0" => :upper }) do
      assert(legacy_spec.matches_current_ruby?)
    end
  end

  def test_completely_ignores_ruby_requirement
    future_gem = Gem::Specification.new do |s|
      s.name = 'future_gem'
      s.version = '1.0.0'
      s.required_ruby_version = '>= 99.0.0'
    end

    with_ignored_dependencies({}) do
      refute(future_gem.matches_current_ruby?)
    end

    with_ignored_dependencies({ "Ruby\0" => :upper }) do
      refute(future_gem.matches_current_ruby?)
    end

    with_ignored_dependencies({ "Ruby\0" => :complete }) do
      assert(future_gem.matches_current_ruby?)
    end
  end

  def test_filters_dependencies_according_to_ignore_rules
    resolver_class = Class.new do
      include Bundler::IgnoreDependency::ResolverPatch
      public :filter_ignored_dependencies
    end
    resolver = resolver_class.new

    with_ignored_dependencies({
                                "Ruby\0" => :upper,
                                'nokogiri' => :complete
                              }) do
      ruby_dep = Gem::Dependency.new("Ruby\0", ['>= 2.7', '< 3.3'])
      nokogiri_dep = Gem::Dependency.new('nokogiri', '>= 1.0')
      rails_dep = Gem::Dependency.new('rails', '>= 7.0')

      result = resolver.filter_ignored_dependencies([ruby_dep, nokogiri_dep, rails_dep])

      ruby_filtered = result.find { |d| d.name == "Ruby\0" }
      assert_equal(Gem::Requirement.new('>= 2.7'), ruby_filtered.requirement)

      refute(result.any? { |d| d.name == 'nokogiri' })

      rails_filtered = result.find { |d| d.name == 'rails' }
      assert_equal(Gem::Requirement.new('>= 7.0'), rails_filtered.requirement)
    end
  end
end

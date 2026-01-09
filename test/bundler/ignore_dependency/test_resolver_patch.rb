# frozen_string_literal: true

require_relative '../../test_helper'

class TestResolverPatch < Minitest::Test
  def setup
    @resolver_class = Class.new do
      include Bundler::IgnoreDependency::ResolverPatch
      public :filter_ignored_dependencies
    end
    @resolver = @resolver_class.new
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

  def teardown
    Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
  end

  def ruby_dependency(requirement)
    Gem::Dependency.new("Ruby\0", requirement)
  end

  def rubygems_dependency(requirement)
    Gem::Dependency.new("RubyGems\0", requirement)
  end

  def gem_dependency(name, requirement)
    Gem::Dependency.new(name, requirement)
  end

  def test_returns_dependencies_unchanged_when_none_ignored
    with_ignored_dependencies({}) do
      deps = [ruby_dependency('>= 2.7'), gem_dependency('rails', '>= 7.0')]
      result = @resolver.filter_ignored_dependencies(deps)
      assert_equal(["Ruby\0", 'rails'], result.map(&:name))
    end
  end

  def test_removes_ruby_dependency_entirely_when_completely_ignored
    with_ignored_dependencies({ "Ruby\0" => :complete }) do
      deps = [
        ruby_dependency(['>= 2.7', '< 3.3']),
        gem_dependency('rails', '>= 7.0')
      ]

      result = @resolver.filter_ignored_dependencies(deps)

      assert_equal(['rails'], result.map(&:name))
    end
  end

  def test_removes_upper_bounds_from_ruby_dependency
    with_ignored_dependencies({ "Ruby\0" => :upper }) do
      deps = [ruby_dependency(['>= 2.7', '< 3.3'])]

      result = @resolver.filter_ignored_dependencies(deps)

      assert_equal("Ruby\0", result.first.name)
      assert_equal(Gem::Requirement.new('>= 2.7'), result.first.requirement)
    end
  end

  def test_removes_rubygems_dependency_entirely_when_completely_ignored
    with_ignored_dependencies({ "RubyGems\0" => :complete }) do
      deps = [
        rubygems_dependency('>= 3.0'),
        gem_dependency('rails', '>= 7.0')
      ]

      result = @resolver.filter_ignored_dependencies(deps)

      assert_equal(['rails'], result.map(&:name))
    end
  end

  def test_removes_gem_dependency_entirely_when_completely_ignored
    with_ignored_dependencies({ 'nokogiri' => :complete }) do
      deps = [
        gem_dependency('nokogiri', '>= 1.0'),
        gem_dependency('rails', '>= 7.0')
      ]

      result = @resolver.filter_ignored_dependencies(deps)

      assert_equal(['rails'], result.map(&:name))
    end
  end

  def test_removes_upper_bounds_from_gem_dependency
    with_ignored_dependencies({ 'nokogiri' => :upper }) do
      deps = [gem_dependency('nokogiri', ['>= 1.0', '< 2.0'])]

      result = @resolver.filter_ignored_dependencies(deps)

      assert_equal('nokogiri', result.first.name)
      assert_equal(Gem::Requirement.new('>= 1.0'), result.first.requirement)
    end
  end

  def test_applies_all_ignore_rules_with_multiple_ignored_dependencies
    with_ignored_dependencies({
                                "Ruby\0" => :upper,
                                "RubyGems\0" => :complete,
                                'nokogiri' => :complete
                              }) do
      deps = [
        ruby_dependency(['>= 2.7', '< 3.3']),
        rubygems_dependency('>= 3.0'),
        gem_dependency('nokogiri', '>= 1.0'),
        gem_dependency('rails', '>= 7.0')
      ]

      result = @resolver.filter_ignored_dependencies(deps)

      # Ruby: upper bounds removed
      ruby_dep = result.find { |d| d.name == "Ruby\0" }
      assert_equal(Gem::Requirement.new('>= 2.7'), ruby_dep.requirement)

      # RubyGems: completely removed
      refute(result.any? { |d| d.name == "RubyGems\0" })

      # nokogiri: completely removed
      refute(result.any? { |d| d.name == 'nokogiri' })

      # rails: unchanged
      rails_dep = result.find { |d| d.name == 'rails' }
      assert_equal(Gem::Requirement.new('>= 7.0'), rails_dep.requirement)
    end
  end
end

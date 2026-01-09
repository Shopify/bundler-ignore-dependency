# frozen_string_literal: true

require_relative '../../test_helper'

class TestLazySpecificationPatch < Minitest::Test
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

  def gem_dependency(name, requirement = '>= 0')
    Gem::Dependency.new(name, requirement)
  end

  def mock_lazy_spec(name, version, dependencies)
    lazy_spec = Bundler::LazySpecification.new(name, Gem::Version.new(version), nil)
    lazy_spec.dependencies = dependencies.dup
    lazy_spec
  end

  def setup
    @patch_class = Class.new do
      extend Bundler::IgnoreDependency::LazySpecificationPatch

      class << self
        public :filter_ignored_dependencies
      end
    end
  end

  def test_returns_lazy_spec_with_dependencies_unchanged_when_none_ignored
    with_ignored_dependencies({}) do
      deps = [gem_dependency('activesupport'), gem_dependency('nokogiri')]
      lazy_spec = mock_lazy_spec('rails', '7.0.0', deps)

      result = @patch_class.filter_ignored_dependencies(lazy_spec)

      assert_equal(%w[activesupport nokogiri], result.dependencies.map(&:name))
    end
  end

  def test_filters_out_ignored_gem_from_dependencies
    with_ignored_dependencies({ 'activerecord' => :complete }) do
      deps = [
        gem_dependency('activesupport'),
        gem_dependency('activerecord'),
        gem_dependency('nokogiri')
      ]
      lazy_spec = mock_lazy_spec('rails', '7.0.0', deps)

      result = @patch_class.filter_ignored_dependencies(lazy_spec)

      assert_equal(%w[activesupport nokogiri], result.dependencies.map(&:name))
    end
  end

  def test_filters_out_all_ignored_gems_from_dependencies
    with_ignored_dependencies({
                                'activerecord' => :complete,
                                'nokogiri' => :complete
                              }) do
      deps = [
        gem_dependency('activesupport'),
        gem_dependency('activerecord'),
        gem_dependency('nokogiri'),
        gem_dependency('rack')
      ]
      lazy_spec = mock_lazy_spec('rails', '7.0.0', deps)

      result = @patch_class.filter_ignored_dependencies(lazy_spec)

      assert_equal(%w[activesupport rack], result.dependencies.map(&:name))
    end
  end

  def test_does_not_filter_out_gem_when_only_upper_bound_ignored
    with_ignored_dependencies({ 'nokogiri' => :upper }) do
      deps = [gem_dependency('activesupport'), gem_dependency('nokogiri')]
      lazy_spec = mock_lazy_spec('rails', '7.0.0', deps)

      result = @patch_class.filter_ignored_dependencies(lazy_spec)

      assert_equal(%w[activesupport nokogiri], result.dependencies.map(&:name))
    end
  end
end

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

  def gem_specification(name, version, dependencies)
    Gem::Specification.new do |s|
      s.name = name
      s.version = version
      dependencies.each do |dep|
        s.add_runtime_dependency(dep.name, dep.requirement)
      end
    end
  end

  def test_from_spec_preserves_dependencies_when_none_ignored
    with_ignored_dependencies({}) do
      deps = [gem_dependency('activesupport'), gem_dependency('nokogiri')]
      spec = gem_specification('rails', '7.0.0', deps)

      lazy_spec = Bundler::LazySpecification.from_spec(spec)

      assert_equal(%w[activesupport nokogiri], lazy_spec.dependencies.map(&:name))
    end
  end

  def test_from_spec_filters_out_ignored_gem_from_dependencies
    with_ignored_dependencies({ 'activerecord' => :complete }) do
      deps = [
        gem_dependency('activesupport'),
        gem_dependency('activerecord'),
        gem_dependency('nokogiri')
      ]
      spec = gem_specification('rails', '7.0.0', deps)

      lazy_spec = Bundler::LazySpecification.from_spec(spec)

      assert_equal(%w[activesupport nokogiri], lazy_spec.dependencies.map(&:name))
    end
  end

  def test_from_spec_filters_out_all_ignored_gems_from_dependencies
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
      spec = gem_specification('rails', '7.0.0', deps)

      lazy_spec = Bundler::LazySpecification.from_spec(spec)

      assert_equal(%w[activesupport rack], lazy_spec.dependencies.map(&:name))
    end
  end

  def test_from_spec_does_not_filter_out_gem_when_only_upper_bound_ignored
    with_ignored_dependencies({ 'nokogiri' => :upper }) do
      deps = [gem_dependency('activesupport'), gem_dependency('nokogiri')]
      spec = gem_specification('rails', '7.0.0', deps)

      lazy_spec = Bundler::LazySpecification.from_spec(spec)

      assert_equal(%w[activesupport nokogiri], lazy_spec.dependencies.map(&:name))
    end
  end
end

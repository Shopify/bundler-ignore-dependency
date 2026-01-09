# frozen_string_literal: true

require_relative '../../spec_helper'

class TestSharedHelpersPatch < Minitest::Test
  def teardown
    # Clean up cache after each test
    Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
  end

  def with_ignored_dependencies(deps)
    definition = Object.new
    definition.define_singleton_method(:ignored_dependencies) { deps }

    Bundler.stub(:definition, definition) do
      Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
      yield
    end
  end

  def gem_dependency(name, requirement = '>= 0')
    Gem::Dependency.new(name, requirement)
  end

  def mock_spec(name, version)
    spec = Object.new
    spec.define_singleton_method(:full_name) { "#{name}-#{version}" }
    spec.define_singleton_method(:name) { name }
    spec.define_singleton_method(:remote) { nil }
    spec
  end

  def test_raises_error_when_new_deps_have_extra_dependencies
    with_ignored_dependencies({}) do
      spec = mock_spec('rails', '7.0.0')
      old_deps = [gem_dependency('activesupport', '= 7.0.0')]
      new_deps = [
        gem_dependency('activesupport', '= 7.0.0'),
        gem_dependency('activerecord', '= 7.0.0')
      ]

      assert_raises(Bundler::APIResponseMismatchError) do
        Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
      end
    end
  end

  def test_does_not_raise_when_dependencies_match
    with_ignored_dependencies({}) do
      spec = mock_spec('rails', '7.0.0')
      old_deps = [gem_dependency('activesupport', '= 7.0.0')]
      new_deps = [gem_dependency('activesupport', '= 7.0.0')]

      # Should not raise
      Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
    end
  end

  def test_does_not_raise_when_ignored_gem_in_new_deps_but_not_old_deps
    with_ignored_dependencies({ 'activerecord' => :complete }) do
      spec = mock_spec('rails', '7.0.0')
      old_deps = [gem_dependency('activesupport', '= 7.0.0')]
      new_deps = [
        gem_dependency('activesupport', '= 7.0.0'),
        gem_dependency('activerecord', '= 7.0.0')
      ]

      # Should not raise
      Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
    end
  end

  def test_still_raises_for_non_ignored_extra_dependencies
    with_ignored_dependencies({ 'activerecord' => :complete }) do
      spec = mock_spec('rails', '7.0.0')
      old_deps = [gem_dependency('activesupport', '= 7.0.0')]
      new_deps = [
        gem_dependency('activesupport', '= 7.0.0'),
        gem_dependency('activerecord', '= 7.0.0'),
        gem_dependency('nokogiri', '= 1.0.0')
      ]

      assert_raises(Bundler::APIResponseMismatchError) do
        Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
      end
    end
  end

  def test_does_not_raise_when_all_extra_deps_are_ignored
    with_ignored_dependencies({
                                'activerecord' => :complete,
                                'actionmailer' => :complete
                              }) do
      spec = mock_spec('rails', '7.0.0')
      old_deps = [gem_dependency('activesupport', '= 7.0.0')]
      new_deps = [
        gem_dependency('activesupport', '= 7.0.0'),
        gem_dependency('activerecord', '= 7.0.0'),
        gem_dependency('actionmailer', '= 7.0.0')
      ]

      # Should not raise
      Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
    end
  end

  def test_still_raises_when_upper_bound_ignored_because_only_complete_ignores_filter
    with_ignored_dependencies({ 'activerecord' => :upper }) do
      spec = mock_spec('rails', '7.0.0')
      old_deps = [gem_dependency('activesupport', '= 7.0.0')]
      new_deps = [
        gem_dependency('activesupport', '= 7.0.0'),
        gem_dependency('activerecord', '= 7.0.0')
      ]

      assert_raises(Bundler::APIResponseMismatchError) do
        Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
      end
    end
  end
end

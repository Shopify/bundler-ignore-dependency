# frozen_string_literal: true

require_relative './test_helper'

class TestBundlerIgnoreDependency < BundlerTest
  def test_ignored_dependencies_returns_empty_hash_when_no_definition
    with_ignored_dependencies(nil) do
      assert_equal({}, Bundler::IgnoreDependency.ignored_dependencies)
    end
  end

  def test_ignored_dependencies_returns_ignored_dependencies_from_definition
    with_ignored_dependencies({ ruby: :upper }) do
      assert_equal({ ruby: :upper }, Bundler::IgnoreDependency.ignored_dependencies)
    end
  end

  def test_ignore_type_for_returns_nil_for_non_ignored_dependency
    with_ignored_dependencies({}) do
      assert_nil(Bundler::IgnoreDependency.ignore_type_for(:ruby))
    end
  end

  def test_ignore_type_for_returns_the_ignore_type_for_ignored_dependency
    with_ignored_dependencies({ ruby: :upper, 'nokogiri' => :complete }) do
      assert_equal(:upper, Bundler::IgnoreDependency.ignore_type_for(:ruby))
      assert_equal(:complete, Bundler::IgnoreDependency.ignore_type_for('nokogiri'))
    end
  end

  def test_completely_ignored_returns_true_when_type_is_complete
    with_ignored_dependencies({ ruby: :complete }) do
      assert(Bundler::IgnoreDependency.completely_ignored?(:ruby))
    end
  end

  def test_completely_ignored_returns_false_when_type_is_upper
    with_ignored_dependencies({ ruby: :upper }) do
      refute(Bundler::IgnoreDependency.completely_ignored?(:ruby))
    end
  end

  def test_completely_ignored_returns_false_when_not_ignored
    with_ignored_dependencies({}) do
      refute(Bundler::IgnoreDependency.completely_ignored?(:ruby))
    end
  end

  def test_upper_bound_ignored_returns_true_when_type_is_upper
    with_ignored_dependencies({ ruby: :upper }) do
      assert(Bundler::IgnoreDependency.upper_bound_ignored?(:ruby))
    end
  end

  def test_upper_bound_ignored_returns_false_when_type_is_complete
    with_ignored_dependencies({ ruby: :complete }) do
      refute(Bundler::IgnoreDependency.upper_bound_ignored?(:ruby))
    end
  end

  def test_upper_bound_ignored_returns_false_when_not_ignored
    with_ignored_dependencies({}) do
      refute(Bundler::IgnoreDependency.upper_bound_ignored?(:ruby))
    end
  end

  def test_remove_upper_bounds_returns_default_requirement_when_nil
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(nil)
    assert_equal(Gem::Requirement.default, filtered)
  end

  def test_remove_upper_bounds_returns_default_requirement_when_empty
    requirement = Gem::Requirement.new([])
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(requirement)
    assert_equal(Gem::Requirement.default, filtered)
  end

  def test_remove_upper_bounds_keeps_lower_bound_with_greater_equal_operator
    requirement = Gem::Requirement.new('>= 2.7')
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(requirement)
    assert_equal(Gem::Requirement.new('>= 2.7'), filtered)
  end

  def test_remove_upper_bounds_keeps_lower_bound_with_greater_operator
    requirement = Gem::Requirement.new('> 2.7')
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(requirement)
    assert_equal(Gem::Requirement.new('> 2.7'), filtered)
  end

  def test_remove_upper_bounds_keeps_exact_version_with_equal_operator
    requirement = Gem::Requirement.new('= 3.0')
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(requirement)
    assert_equal(Gem::Requirement.new('= 3.0'), filtered)
  end

  def test_remove_upper_bounds_returns_default_requirement_with_less_operator
    requirement = Gem::Requirement.new('< 4.0')
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(requirement)
    assert_equal(Gem::Requirement.default, filtered)
  end

  def test_remove_upper_bounds_returns_default_requirement_with_less_equal_operator
    requirement = Gem::Requirement.new('<= 3.2')
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(requirement)
    assert_equal(Gem::Requirement.default, filtered)
  end

  def test_remove_upper_bounds_removes_upper_bound_and_keeps_lower_bound_with_mixed_bounds
    requirement = Gem::Requirement.new(['>= 2.7', '< 3.1'])
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(requirement)
    assert_equal(Gem::Requirement.new('>= 2.7'), filtered)
  end

  def test_remove_upper_bounds_converts_pessimistic_operator_to_greater_equal_equivalent
    requirement = Gem::Requirement.new('~> 2.7')
    filtered = Bundler::IgnoreDependency.remove_upper_bounds(requirement)
    assert_equal(Gem::Requirement.new('>= 2.7'), filtered)
  end

  def test_apply_ignore_rule_returns_default_requirement_when_completely_ignored
    requirement = Gem::Requirement.new(['>= 2.7', '< 3.3'])
    with_ignored_dependencies({ ruby: :complete }) do
      result = Bundler::IgnoreDependency.apply_ignore_rule(requirement, :ruby)
      assert_equal(Gem::Requirement.default, result)
    end
  end

  def test_apply_ignore_rule_removes_upper_bounds_when_upper_bound_ignored
    requirement = Gem::Requirement.new(['>= 2.7', '< 3.3'])
    with_ignored_dependencies({ ruby: :upper }) do
      result = Bundler::IgnoreDependency.apply_ignore_rule(requirement, :ruby)
      assert_equal(Gem::Requirement.new('>= 2.7'), result)
    end
  end

  def test_apply_ignore_rule_returns_original_requirement_when_not_ignored
    requirement = Gem::Requirement.new(['>= 2.7', '< 3.3'])
    with_ignored_dependencies({}) do
      result = Bundler::IgnoreDependency.apply_ignore_rule(requirement, :ruby)
      assert_equal(requirement, result)
    end
  end
end

# frozen_string_literal: true

require_relative "../test_helper"

class TestSharedHelpersPatch < BundlerTest
  def test_raises_error_when_new_deps_have_extra_dependencies
    with_ignored_dependencies({}) do
      spec = mock_spec("rails", "7.0.0")
      old_deps = [gem_dependency("activesupport", "= 7.0.0")]
      new_deps = [
        gem_dependency("activesupport", "= 7.0.0"),
        gem_dependency("activerecord", "= 7.0.0"),
      ]

      assert_raises(Bundler::APIResponseMismatchError) do
        Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
      end
    end
  end

  def test_does_not_raise_when_dependencies_match
    with_ignored_dependencies({}) do
      spec = mock_spec("rails", "7.0.0")
      old_deps = [gem_dependency("activesupport", "= 7.0.0")]
      new_deps = [gem_dependency("activesupport", "= 7.0.0")]

      # Should not raise
      Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
    end
  end

  def test_does_not_raise_when_ignored_gem_in_new_deps_but_not_old_deps
    with_ignored_dependencies({ "activerecord" => :complete }) do
      spec = mock_spec("rails", "7.0.0")
      old_deps = [gem_dependency("activesupport", "= 7.0.0")]
      new_deps = [
        gem_dependency("activesupport", "= 7.0.0"),
        gem_dependency("activerecord", "= 7.0.0"),
      ]

      # Should not raise
      Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
    end
  end

  def test_still_raises_for_non_ignored_extra_dependencies
    with_ignored_dependencies({ "activerecord" => :complete }) do
      spec = mock_spec("rails", "7.0.0")
      old_deps = [gem_dependency("activesupport", "= 7.0.0")]
      new_deps = [
        gem_dependency("activesupport", "= 7.0.0"),
        gem_dependency("activerecord", "= 7.0.0"),
        gem_dependency("nokogiri", "= 1.0.0"),
      ]

      assert_raises(Bundler::APIResponseMismatchError) do
        Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
      end
    end
  end

  def test_does_not_raise_when_all_extra_deps_are_ignored
    with_ignored_dependencies({
      "activerecord" => :complete,
      "actionmailer" => :complete,
    }) do
      spec = mock_spec("rails", "7.0.0")
      old_deps = [gem_dependency("activesupport", "= 7.0.0")]
      new_deps = [
        gem_dependency("activesupport", "= 7.0.0"),
        gem_dependency("activerecord", "= 7.0.0"),
        gem_dependency("actionmailer", "= 7.0.0"),
      ]

      # Should not raise
      Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
    end
  end

  def test_still_raises_when_upper_bound_ignored_because_only_complete_ignores_filter
    with_ignored_dependencies({ "activerecord" => :upper }) do
      spec = mock_spec("rails", "7.0.0")
      old_deps = [gem_dependency("activesupport", "= 7.0.0")]
      new_deps = [
        gem_dependency("activesupport", "= 7.0.0"),
        gem_dependency("activerecord", "= 7.0.0"),
      ]

      assert_raises(Bundler::APIResponseMismatchError) do
        Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
      end
    end
  end
end

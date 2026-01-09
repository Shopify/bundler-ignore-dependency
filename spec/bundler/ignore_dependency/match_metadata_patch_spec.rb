# frozen_string_literal: true

require_relative '../../spec_helper'

class TestMatchMetadataPatch < Minitest::Test
  def with_ignored_dependencies(deps)
    definition = Object.new
    definition.define_singleton_method(:ignored_dependencies) { deps }

    Bundler.stub(:definition, definition) do
      Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
      yield
    end
  end

  def teardown
    Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
  end

  def spec_with_requirements(ruby: nil, rubygems: nil)
    Gem::Specification.new do |s|
      s.name = 'test_gem'
      s.version = '1.0.0'
      s.required_ruby_version = ruby if ruby
      s.required_rubygems_version = rubygems if rubygems
    end
  end

  def test_matches_current_ruby_returns_true_regardless_of_requirement_when_completely_ignored
    with_ignored_dependencies({ "Ruby\0" => :complete }) do
      spec = spec_with_requirements(ruby: '>= 99.0.0')
      assert(spec.matches_current_ruby?)
    end
  end

  def test_matches_current_ruby_returns_true_when_only_upper_bound_excludes_current_ruby
    skip('Test requires Ruby >= 3.0') if Gem.ruby_version < Gem::Version.new('3.0.0')

    with_ignored_dependencies({ "Ruby\0" => :upper }) do
      spec = spec_with_requirements(ruby: ['>= 2.7', '< 3.0'])
      assert(spec.matches_current_ruby?)
    end
  end

  def test_matches_current_ruby_returns_false_when_lower_bound_excludes_current_ruby
    with_ignored_dependencies({ "Ruby\0" => :upper }) do
      spec = spec_with_requirements(ruby: '>= 99.0.0')
      refute(spec.matches_current_ruby?)
    end
  end

  def test_matches_current_ruby_returns_false_when_requirement_excludes_current_ruby
    skip('Test requires Ruby >= 3.0') if Gem.ruby_version < Gem::Version.new('3.0.0')

    with_ignored_dependencies({}) do
      spec = spec_with_requirements(ruby: ['>= 2.7', '< 3.0'])
      refute(spec.matches_current_ruby?)
    end
  end

  def test_matches_current_ruby_returns_true_when_requirement_matches_current_ruby
    with_ignored_dependencies({}) do
      spec = spec_with_requirements(ruby: '>= 2.7')
      assert(spec.matches_current_ruby?)
    end
  end

  def test_matches_current_rubygems_returns_true_regardless_of_requirement_when_completely_ignored
    with_ignored_dependencies({ "RubyGems\0" => :complete }) do
      spec = spec_with_requirements(rubygems: '>= 99.0.0')
      assert(spec.matches_current_rubygems?)
    end
  end

  def test_matches_current_rubygems_removes_upper_bound_from_requirement
    with_ignored_dependencies({ "RubyGems\0" => :upper }) do
      current_version = Gem.rubygems_version
      upper_bound = Gem::Version.new("#{current_version.segments[0]}.0.0")

      spec = spec_with_requirements(rubygems: ['>= 1.0', "< #{upper_bound}"])

      assert(spec.matches_current_rubygems?) if current_version >= Gem::Version.new('1.0')
    end
  end

  def test_matches_current_rubygems_returns_true_when_requirement_matches_current_rubygems
    with_ignored_dependencies({}) do
      spec = spec_with_requirements(rubygems: '>= 1.0')
      assert(spec.matches_current_rubygems?)
    end
  end
end

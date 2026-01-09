# frozen_string_literal: true

require_relative '../test_helper'

class BundlerTest < Minitest::Test
  private

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

  def gem_dependency(name, requirement = '>= 0')
    Gem::Dependency.new(name, requirement)
  end

  def ruby_dependency(requirement)
    Gem::Dependency.new("Ruby\0", requirement)
  end

  def rubygems_dependency(requirement)
    Gem::Dependency.new("RubyGems\0", requirement)
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

  def spec_with_requirements(ruby: nil, rubygems: nil)
    Gem::Specification.new do |s|
      s.name = 'test_gem'
      s.version = '1.0.0'
      s.required_ruby_version = ruby if ruby
      s.required_rubygems_version = rubygems if rubygems
    end
  end

  def mock_spec(name, version)
    spec = Object.new
    spec.define_singleton_method(:full_name) { "#{name}-#{version}" }
    spec.define_singleton_method(:name) { name }
    spec.define_singleton_method(:remote) { nil }
    spec
  end

  def teardown
    Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
  end
end

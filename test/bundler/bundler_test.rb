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

  def teardown
    Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
  end
end

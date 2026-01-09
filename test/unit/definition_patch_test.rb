# frozen_string_literal: true

require_relative "test_helper"

class TestDefinitionPatch < BundlerTest
  def setup
    @definition = Bundler::Definition.new(nil, [], Bundler::SourceList.new, {})
  end

  def test_ignored_dependencies_defaults_to_empty_hash
    assert_empty(@definition.ignored_dependencies)
  end

  def test_ignored_dependencies_can_be_set_to_hash
    @definition.ignored_dependencies = { ruby: :upper, "nokogiri" => :complete }
    assert_equal({ ruby: :upper, "nokogiri" => :complete }, @definition.ignored_dependencies)
  end
end

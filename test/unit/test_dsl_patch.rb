# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'

class TestDslPatch < BundlerTest
  def setup
    @dsl = Bundler::Dsl.new
  end

  def test_ignore_dependency_defaults_to_empty_hash
    assert_equal({}, @dsl.ignored_dependencies)
  end

  def test_ignore_dependency_with_ruby_stores_complete_type_by_default
    @dsl.ignore_dependency!(:ruby)
    assert_equal({ "Ruby\0" => :complete }, @dsl.ignored_dependencies)
  end

  def test_ignore_dependency_with_ruby_stores_upper_type_when_specified
    @dsl.ignore_dependency!(:ruby, type: :upper)
    assert_equal({ "Ruby\0" => :upper }, @dsl.ignored_dependencies)
  end

  def test_ignore_dependency_with_rubygems_stores_complete_type_by_default
    @dsl.ignore_dependency!(:rubygems)
    assert_equal({ "RubyGems\0" => :complete }, @dsl.ignored_dependencies)
  end

  def test_ignore_dependency_with_rubygems_stores_upper_type_when_specified
    @dsl.ignore_dependency!(:rubygems, type: :upper)
    assert_equal({ "RubyGems\0" => :upper }, @dsl.ignored_dependencies)
  end

  def test_ignore_dependency_with_gem_name_string_stores_complete_type_by_default
    @dsl.ignore_dependency!('nokogiri')
    assert_equal({ 'nokogiri' => :complete }, @dsl.ignored_dependencies)
  end

  def test_ignore_dependency_with_gem_name_string_stores_upper_type_when_specified
    @dsl.ignore_dependency!('nokogiri', type: :upper)
    assert_equal({ 'nokogiri' => :upper }, @dsl.ignored_dependencies)
  end

  def test_ignore_dependency_with_multiple_dependencies
    @dsl.ignore_dependency!(:ruby, type: :upper)
    @dsl.ignore_dependency!(:rubygems)
    @dsl.ignore_dependency!('nokogiri')

    assert_equal({
                   "Ruby\0" => :upper,
                   "RubyGems\0" => :complete,
                   'nokogiri' => :complete
                 }, @dsl.ignored_dependencies)
  end

  def test_ignore_dependency_raises_error_for_invalid_type
    assert_raises(ArgumentError) do
      @dsl.ignore_dependency!(:ruby, type: :invalid)
    end
  end

  def test_ignore_dependency_raises_error_for_invalid_dependency_name
    assert_raises(ArgumentError) do
      @dsl.ignore_dependency!(123)
    end
  end

  def test_to_definition_passes_ignored_dependencies_to_definition
    lockfile = Pathname.new(Dir.tmpdir).join('Gemfile.lock')
    original_method = begin
      Bundler::SharedHelpers.method(:pwd)
    rescue StandardError
      nil
    end

    Bundler::SharedHelpers.define_singleton_method(:pwd) { Dir.tmpdir }
    begin
      @dsl.source('https://rubygems.org')
      @dsl.ignore_dependency!(:ruby, type: :upper)
      @dsl.ignore_dependency!('nokogiri')

      definition = @dsl.to_definition(lockfile, {})

      assert_equal({
                     "Ruby\0" => :upper,
                     'nokogiri' => :complete
                   }, definition.ignored_dependencies)
    ensure
      if original_method
        Bundler::SharedHelpers.define_singleton_method(:pwd, &original_method)
      elsif Bundler::SharedHelpers.respond_to?(:pwd)
        Bundler::SharedHelpers.singleton_class.undef_method(:pwd)
      end
    end
  end

  def test_to_definition_passes_empty_hash_when_no_dependencies_ignored
    lockfile = Pathname.new(Dir.tmpdir).join('Gemfile.lock')
    original_method = begin
      Bundler::SharedHelpers.method(:pwd)
    rescue StandardError
      nil
    end

    Bundler::SharedHelpers.define_singleton_method(:pwd) { Dir.tmpdir }
    begin
      @dsl.source('https://rubygems.org')
      definition = @dsl.to_definition(lockfile, {})

      assert_equal({}, definition.ignored_dependencies)
    ensure
      if original_method
        Bundler::SharedHelpers.define_singleton_method(:pwd, &original_method)
      elsif Bundler::SharedHelpers.respond_to?(:pwd)
        Bundler::SharedHelpers.singleton_class.undef_method(:pwd)
      end
    end
  end
end

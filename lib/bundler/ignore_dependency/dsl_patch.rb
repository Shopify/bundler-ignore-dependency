# frozen_string_literal: true

require 'bundler/dsl'

module Bundler
  module IgnoreDependency
    # Adds ignore_dependency! method to Bundler::Dsl (Gemfile DSL)
    #
    # Purpose: Provides the user-facing API for specifying which dependencies
    # should be ignored. Users call ignore_dependency! in their Gemfile to mark
    # dependencies (Ruby, RubyGems, or gems) that should be filtered out of
    # dependency resolution and version constraint checking.
    #
    # When ignore_dependency! is called, it normalizes the dependency names
    # (e.g., :ruby -> "Ruby\0") and stores them in @ignored_dependencies.
    # These settings are then transferred to the Definition object via to_definition().
    module DslPatch
      def initialize
        super
        @ignored_dependencies = {}
      end

      def ignore_dependency!(name, type: :complete)
        unless %i[complete upper].include?(type)
          raise ArgumentError, "type must be :complete or :upper, got #{type.inspect}"
        end

        key = normalize_dependency_name(name)
        ignored_dependencies[key] = type
      end

      def to_definition(lockfile, unlock)
        definition = super
        definition.ignored_dependencies = ignored_dependencies.dup
        definition
      end

      def ignored_dependencies
        @ignored_dependencies ||= {}
      end

      private

      def normalize_dependency_name(name)
        case name
        when :ruby
          IgnoreDependency::RUBY_DEPENDENCY_NAME
        when :rubygems
          IgnoreDependency::RUBYGEMS_DEPENDENCY_NAME
        when String
          name
        else
          raise ArgumentError, 'dependency name must be :ruby, :rubygems, or a gem name string'
        end
      end
    end
  end

  Dsl.prepend(IgnoreDependency::DslPatch)
end

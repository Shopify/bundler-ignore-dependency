# frozen_string_literal: true

require "bundler/dsl"

module Bundler
  module IgnoreDependency
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
          raise ArgumentError, "dependency name must be :ruby, :rubygems, or a gem name string"
        end
      end
    end
  end

  Dsl.prepend(IgnoreDependency::DslPatch)
end

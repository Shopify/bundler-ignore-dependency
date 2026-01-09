# frozen_string_literal: true

require "bundler/definition"

module Bundler
  module IgnoreDependency
    # Adds ignored_dependencies attribute to Bundler::Definition
    #
    # Purpose: Stores the set of dependencies that should be ignored during
    # dependency resolution. This attribute is populated by DSLPatch from the
    # Gemfile's ignore_dependency! directives and is accessed by all other patches
    # to determine which dependencies to filter.
    #
    # The attribute acts as the central source of truth for ignored dependencies
    # throughout the entire dependency resolution and materialization process.
    module DefinitionPatch
      def ignored_dependencies
        @ignored_dependencies ||= {}
      end

      attr_writer :ignored_dependencies
    end
  end

  Definition.prepend(IgnoreDependency::DefinitionPatch)
end

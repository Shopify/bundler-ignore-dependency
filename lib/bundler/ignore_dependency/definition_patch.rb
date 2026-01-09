# frozen_string_literal: true

require 'bundler/definition'

module Bundler
  module IgnoreDependency
    module DefinitionPatch
      def ignored_dependencies
        @ignored_dependencies ||= {}
      end

      attr_writer :ignored_dependencies
    end
  end

  Definition.prepend(IgnoreDependency::DefinitionPatch)
end

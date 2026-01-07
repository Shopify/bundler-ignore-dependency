# frozen_string_literal: true

require "bundler/definition"

module Bundler
  module IgnoreRubyUpperBound
    module DefinitionPatch
      attr_accessor :ignored_dependencies

      def ignored_dependencies
        @ignored_dependencies ||= {}
      end
    end
  end

  Definition.prepend(IgnoreRubyUpperBound::DefinitionPatch)
end

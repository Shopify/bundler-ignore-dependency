# frozen_string_literal: true

require "bundler/definition"

module Bundler
  module IgnoreRubyUpperBound
    module DefinitionPatch
      attr_accessor :ignore_ruby_upper_bound
    end
  end

  Definition.prepend(IgnoreRubyUpperBound::DefinitionPatch)
end

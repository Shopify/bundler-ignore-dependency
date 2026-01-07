# frozen_string_literal: true

require "bundler/dsl"

module Bundler
  module IgnoreRubyUpperBound
    module DslPatch
      def initialize
        super
        @ignore_ruby_upper_bound = false
      end

      def ignore_ruby_upper_bound!
        @ignore_ruby_upper_bound = true
      end

      def to_definition(lockfile, unlock)
        definition = super
        definition.ignore_ruby_upper_bound = @ignore_ruby_upper_bound
        definition
      end
    end
  end

  Dsl.prepend(IgnoreRubyUpperBound::DslPatch)
end

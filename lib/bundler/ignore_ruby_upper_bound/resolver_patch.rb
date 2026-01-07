# frozen_string_literal: true

require "bundler/resolver"

module Bundler
  module IgnoreRubyUpperBound
    module ResolverPatch
      private

      def to_dependency_hash(dependencies, packages)
        super(filter_ruby_upper_bounds(dependencies), packages)
      end

      def filter_ruby_upper_bounds(deps)
        return deps unless Bundler.definition&.ignore_ruby_upper_bound

        deps.map do |dep|
          if dep.name == "Ruby\0"
            filtered = IgnoreRubyUpperBound.remove_upper_bounds(dep.requirement)
            Gem::Dependency.new(dep.name, filtered)
          else
            dep
          end
        end
      end
    end
  end

  Resolver.prepend(IgnoreRubyUpperBound::ResolverPatch)
end

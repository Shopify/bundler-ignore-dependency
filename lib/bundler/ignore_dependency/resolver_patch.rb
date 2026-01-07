# frozen_string_literal: true

require "bundler/resolver"

module Bundler
  module IgnoreDependency
    module ResolverPatch
      private

      def to_dependency_hash(dependencies, packages)
        super(filter_ignored_dependencies(dependencies), packages)
      end

      def filter_ignored_dependencies(deps)
        ignored = IgnoreDependency.ignored_dependencies
        return deps if ignored.empty?

        deps.filter_map do |dep|
          filter_dependency(dep, ignored)
        end
      end

      def filter_dependency(dep, ignored)
        case ignored[dep.name]
        when :complete
          nil # Remove the dependency entirely
        when :upper
          apply_upper_bound_filter(dep)
        else
          dep
        end
      end

      def apply_upper_bound_filter(dep)
        filtered = IgnoreDependency.remove_upper_bounds(dep.requirement)
        Gem::Dependency.new(dep.name, filtered)
      end
    end
  end

  Resolver.prepend(IgnoreDependency::ResolverPatch)
end

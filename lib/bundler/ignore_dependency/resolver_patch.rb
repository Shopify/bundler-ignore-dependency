# frozen_string_literal: true

require "bundler/resolver"

module Bundler
  module IgnoreDependency
    # Filters dependencies during Bundler's resolution phase
    #
    # Purpose: This is the core filtering mechanism. During dependency resolution,
    # it removes or modifies dependencies based on ignore rules:
    # - Completely ignored dependencies are removed entirely (not part of resolution)
    # - Upper bound ignored dependencies have their upper bounds removed (e.g., < 3.0)
    #   while keeping lower bounds (e.g., >= 2.7)
    #
    # This ensures that:
    # 1. Completely ignored gems don't participate in dependency resolution at all
    # 2. Upper bound ignored constraints don't prevent newer versions from being resolved
    # 3. Lower bounds are still respected (e.g., minimum version requirements)
    #
    # This filtering happens before the resolver sees dependencies, making it the
    # primary mechanism for excluding dependencies from the resolution process.
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

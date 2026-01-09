# frozen_string_literal: true

module Bundler
  module IgnoreDependency
    # Removes completely ignored gems from resolved gem specifications
    #
    # Purpose: After dependency resolution, LazySpecification objects are created
    # from resolved specs. This patch intercepts that creation to remove completely
    # ignored gems from the dependencies list.
    #
    # Critical for: Preventing ignored gems from appearing in the lockfile
    # Without this patch, completely ignored gems would still appear in Gemfile.lock
    # even though they're not actually being resolved.
    #
    # Flow: ResolverPatch filters during resolution → LazySpecificationPatch filters
    # the resolved specs → MaterializationPatch prevents fetching
    module LazySpecificationPatch
      def from_spec(s)
        filter_ignored_dependencies(super)
      end

      private

      def filter_ignored_dependencies(lazy_spec)
        ignored_names = IgnoreDependency.completely_ignored_gem_names

        if ignored_names.any?
          lazy_spec.dependencies.reject! do |dep|
            ignored_names.include?(dep.name)
          end
        end

        lazy_spec
      end
    end
  end

  LazySpecification.singleton_class.prepend(IgnoreDependency::LazySpecificationPatch)
end

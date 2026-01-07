# frozen_string_literal: true

module Bundler
  module IgnoreDependency
    # Patch LazySpecification.from_spec to filter out ignored dependencies
    # This ensures resolved specs don't have ignored gems in their dependencies
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

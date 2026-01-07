# frozen_string_literal: true

require "bundler/shared_helpers"

module Bundler
  module IgnoreDependency
    module SharedHelpersPatch
      def ensure_same_dependencies(spec, old_deps, new_deps)
        super(spec, old_deps, filter_ignored_dependencies(new_deps))
      end

      private

      def filter_ignored_dependencies(deps)
        ignored_names = IgnoreDependency.completely_ignored_gem_names
        return deps if ignored_names.empty?

        deps.reject { |dep| ignored_names.include?(dep.name) }
      end
    end
  end

  SharedHelpers.singleton_class.prepend(IgnoreDependency::SharedHelpersPatch)
end

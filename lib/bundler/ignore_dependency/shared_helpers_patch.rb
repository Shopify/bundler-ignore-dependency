# frozen_string_literal: true

require "bundler/shared_helpers"

module Bundler
  module IgnoreDependency
    # Skips API validation for completely ignored gem dependencies
    #
    # Purpose: When Bundler fetches gem metadata from rubygems.org or other
    # sources, it validates that the dependencies reported by the server match
    # what was previously resolved. This validation raises an error if there's
    # a mismatch (e.g., when a gem's dependencies change between versions).
    #
    # For completely ignored gems, we filter them out before validation because:
    # 1. They won't be installed anyway
    # 2. We don't care about their dependency structure
    # 3. Differences in their deps shouldn't cause validation errors
    #
    # Without this patch, if a completely ignored gem has different dependencies
    # in the API than before, bundle install would fail with APIResponseMismatchError.
    module SharedHelpersPatch
      def ensure_same_dependencies(spec, old_deps, new_deps)
        super(spec, old_deps, IgnoreDependency.filter_ignored_gem_dependencies(new_deps))
      end
    end
  end

  SharedHelpers.singleton_class.prepend(IgnoreDependency::SharedHelpersPatch)
end

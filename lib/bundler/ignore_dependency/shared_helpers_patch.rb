# frozen_string_literal: true

require 'bundler/shared_helpers'

module Bundler
  module IgnoreDependency
    module SharedHelpersPatch
      def ensure_same_dependencies(spec, old_deps, new_deps)
        super(spec, old_deps, IgnoreDependency.filter_ignored_gem_dependencies(new_deps))
      end
    end
  end

  SharedHelpers.singleton_class.prepend(IgnoreDependency::SharedHelpersPatch)
end

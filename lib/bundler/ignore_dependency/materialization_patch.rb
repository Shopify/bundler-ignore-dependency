# frozen_string_literal: true

require 'bundler/materialization'

module Bundler
  module IgnoreDependency
    # Patch Materialization#dependencies to filter out ignored dependencies
    # This prevents Bundler from trying to materialize ignored gems
    module MaterializationPatch
      def dependencies
        deps = super
        ignored_names = IgnoreDependency.completely_ignored_gem_names

        return deps if ignored_names.empty?

        deps.reject { |dep, _platform| ignored_names.include?(dep.name) }
      end
    end
  end

  Materialization.prepend(IgnoreDependency::MaterializationPatch)
end

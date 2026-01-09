# frozen_string_literal: true

require "bundler/materialization"

module Bundler
  module IgnoreDependency
    # Prevents fetching/installing of completely ignored gems
    #
    # Purpose: During the materialization phase, Bundler prepares to actually
    # install/download gems. This patch removes completely ignored gems from
    # the list of dependencies to materialize.
    #
    # Critical for: Preventing unnecessary gem downloads and avoiding network
    # errors when the server doesn't have compatible versions of ignored gems.
    #
    # Without this patch:
    # - Bundler would try to fetch completely ignored gems from rubygems.org
    # - If the gem doesn't exist or has no compatible platform, installation fails
    # - Network bandwidth is wasted downloading gems that won't be used
    #
    # Flow: ResolverPatch filters during resolution → LazySpecificationPatch
    # filters specs → MaterializationPatch prevents fetching
    module MaterializationPatch
      def dependencies
        deps = super
        ignored_names = IgnoreDependency.completely_ignored_gem_names

        return deps if ignored_names.empty?

        deps.reject { |dep, _| ignored_names.include?(dep.name) }
      end
    end
  end

  Materialization.prepend(IgnoreDependency::MaterializationPatch)
end

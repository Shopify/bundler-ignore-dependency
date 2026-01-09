# frozen_string_literal: true

require "bundler/match_metadata"

module Bundler
  module IgnoreDependency
    # Overrides Ruby and RubyGems version matching checks
    #
    # Purpose: Allows gems with restrictive Ruby/RubyGems version requirements
    # to be installed even when the current environment doesn't meet those constraints.
    #
    # Behaviors:
    # - When Ruby is completely ignored: accepts gems regardless of required_ruby_version
    # - When Ruby upper bound is ignored: removes upper bounds from requirements,
    #   allowing newer Ruby versions (e.g., Ruby 4.0 can install gems marked as < 4.0)
    # - Same logic applies to RubyGems version matching
    #
    # Example: A gem with required_ruby_version = [">= 2.7", "< 3.0"] can be installed
    # on Ruby 3.2 when ignore_dependency! :ruby, type: :upper is used.
    module MatchMetadataPatch
      def matches_current_ruby?
        matches_version?(:ruby, Gem.ruby_version, @required_ruby_version)
      end

      def matches_current_rubygems?
        matches_version?(:rubygems, Gem.rubygems_version, @required_rubygems_version)
      end

      private

      def matches_version?(dependency_type, current_version, required_version)
        return true if IgnoreDependency.send("#{dependency_type}_completely_ignored?")

        requirement = if IgnoreDependency.send("#{dependency_type}_upper_bound_ignored?")
          IgnoreDependency.remove_upper_bounds(required_version)
        else
          required_version
        end

        requirement.satisfied_by?(current_version)
      end
    end
  end

  MatchMetadata.prepend(IgnoreDependency::MatchMetadataPatch)
end

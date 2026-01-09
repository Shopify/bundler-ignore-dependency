# frozen_string_literal: true

require 'bundler/match_metadata'

module Bundler
  module IgnoreDependency
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

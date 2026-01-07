# frozen_string_literal: true

require "bundler/match_metadata"

module Bundler
  module IgnoreRubyUpperBound
    module MatchMetadataPatch
      def matches_current_ruby?
        return true if IgnoreRubyUpperBound.completely_ignored?(:ruby)

        requirement = if IgnoreRubyUpperBound.upper_bound_ignored?(:ruby)
          IgnoreRubyUpperBound.remove_upper_bounds(@required_ruby_version)
        else
          @required_ruby_version
        end

        requirement.satisfied_by?(Gem.ruby_version)
      end

      def matches_current_rubygems?
        return true if IgnoreRubyUpperBound.completely_ignored?(:rubygems)

        requirement = if IgnoreRubyUpperBound.upper_bound_ignored?(:rubygems)
          IgnoreRubyUpperBound.remove_upper_bounds(@required_rubygems_version)
        else
          @required_rubygems_version
        end

        requirement.satisfied_by?(Gem.rubygems_version)
      end
    end
  end

  MatchMetadata.prepend(IgnoreRubyUpperBound::MatchMetadataPatch)
end

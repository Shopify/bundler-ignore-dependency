# frozen_string_literal: true

require "bundler/match_metadata"

module Bundler
  module IgnoreRubyUpperBound
    module MatchMetadataPatch
      def matches_current_ruby?
        requirement = if Bundler.definition&.ignore_ruby_upper_bound
          IgnoreRubyUpperBound.remove_upper_bounds(@required_ruby_version)
        else
          @required_ruby_version
        end
        requirement.satisfied_by?(Gem.ruby_version)
      end
    end
  end

  MatchMetadata.prepend(IgnoreRubyUpperBound::MatchMetadataPatch)
end

# frozen_string_literal: true

module Bundler
  module IgnoreRubyUpperBound
    LOWER_BOUND_OPERATORS = [">=", ">", "="].freeze

    def self.remove_upper_bounds(requirement)
      return Gem::Requirement.default if requirement.nil? || requirement.none?

      lower_bounds = requirement.requirements.filter_map do |op, version|
        if LOWER_BOUND_OPERATORS.include?(op)
          [op, version]
        elsif op == "~>"
          # Pessimistic operator ~> X.Y means >= X.Y AND < X+1.0
          # We keep only the lower bound part
          [">=", version]
        end
        # Skip < and <= operators (upper bounds)
      end

      return Gem::Requirement.default if lower_bounds.empty?

      Gem::Requirement.new(lower_bounds.map { |op, v| "#{op} #{v}" })
    end
  end
end

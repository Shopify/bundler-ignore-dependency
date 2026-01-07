# frozen_string_literal: true

require "bundler/resolver"

module Bundler
  module IgnoreRubyUpperBound
    module ResolverPatch
      # Maps internal dependency names to our ignore rule names
      METADATA_DEPENDENCY_MAP = {
        "Ruby\0" => :ruby,
        "RubyGems\0" => :rubygems
      }.freeze

      private

      def to_dependency_hash(dependencies, packages)
        super(filter_ignored_dependencies(dependencies), packages)
      end

      def filter_ignored_dependencies(deps)
        ignored = IgnoreRubyUpperBound.ignored_dependencies
        return deps if ignored.empty?

        deps.filter_map do |dep|
          filter_dependency(dep, ignored)
        end
      end

      def filter_dependency(dep, ignored)
        ignore_name = dependency_ignore_name(dep)
        ignore_type = ignored[ignore_name]

        return dep unless ignore_type

        case ignore_type
        when :complete
          nil # Remove the dependency entirely
        when :upper
          apply_upper_bound_filter(dep)
        else
          dep
        end
      end

      def dependency_ignore_name(dep)
        # Check if it's a metadata dependency (Ruby, RubyGems)
        METADATA_DEPENDENCY_MAP[dep.name] || dep.name
      end

      def apply_upper_bound_filter(dep)
        filtered = IgnoreRubyUpperBound.remove_upper_bounds(dep.requirement)
        Gem::Dependency.new(dep.name, filtered)
      end
    end
  end

  Resolver.prepend(IgnoreRubyUpperBound::ResolverPatch)
end

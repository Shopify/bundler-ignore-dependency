# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe "ignore_ruby_upper_bound integration" do
  # These tests verify the plugin works end-to-end by simulating
  # what happens when Bundler evaluates a Gemfile with the directive

  describe "Gemfile DSL integration" do
    it "can be enabled via Gemfile DSL and affects gem resolution" do
      # Create a DSL instance and evaluate a Gemfile-like block
      dsl = Bundler::Dsl.new

      # Simulate evaluating: ignore_ruby_upper_bound!
      dsl.ignore_ruby_upper_bound!

      # Verify the flag is set
      expect(dsl.instance_variable_get(:@ignore_ruby_upper_bound)).to be true
    end

    it "propagates the setting through to Definition" do
      Dir.mktmpdir do |dir|
        gemfile_path = File.join(dir, "Gemfile")
        lockfile_path = File.join(dir, "Gemfile.lock")

        File.write(gemfile_path, <<~GEMFILE)
          source "https://rubygems.org"
          ignore_ruby_upper_bound!
        GEMFILE

        # Parse the Gemfile
        allow(Bundler::SharedHelpers).to receive(:pwd).and_return(dir)

        definition = Bundler::Definition.build(gemfile_path, lockfile_path, {})

        expect(definition.ignore_ruby_upper_bound).to be true
      end
    end

    it "defaults to false when directive is not present" do
      Dir.mktmpdir do |dir|
        gemfile_path = File.join(dir, "Gemfile")
        lockfile_path = File.join(dir, "Gemfile.lock")

        File.write(gemfile_path, <<~GEMFILE)
          source "https://rubygems.org"
        GEMFILE

        allow(Bundler::SharedHelpers).to receive(:pwd).and_return(dir)

        definition = Bundler::Definition.build(gemfile_path, lockfile_path, {})

        expect(definition.ignore_ruby_upper_bound).to be false
      end
    end
  end

  describe "MatchMetadata integration" do
    # Test that the patch correctly filters Ruby requirements when evaluating
    # gem compatibility

    let(:spec_with_upper_bound) do
      Gem::Specification.new do |s|
        s.name = "test_gem"
        s.version = "1.0.0"
        # This excludes Ruby 3.x
        s.required_ruby_version = [">= 2.7.0", "< 3.0.0"]
      end
    end

    let(:spec_with_pessimistic) do
      Gem::Specification.new do |s|
        s.name = "pessimistic_gem"
        s.version = "1.0.0"
        # ~> 2.7 means >= 2.7.0 and < 3.0
        s.required_ruby_version = "~> 2.7"
      end
    end

    context "on Ruby 3.x" do
      before do
        skip "Test requires Ruby >= 3.0" if Gem.ruby_version < Gem::Version.new("3.0.0")
      end

      it "rejects incompatible gem when plugin is disabled" do
        definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: false)
        allow(Bundler).to receive(:definition).and_return(definition)

        expect(spec_with_upper_bound.matches_current_ruby?).to be false
      end

      it "accepts incompatible gem when plugin is enabled" do
        definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: true)
        allow(Bundler).to receive(:definition).and_return(definition)

        expect(spec_with_upper_bound.matches_current_ruby?).to be true
      end

      it "handles pessimistic constraints when plugin is enabled" do
        definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: true)
        allow(Bundler).to receive(:definition).and_return(definition)

        expect(spec_with_pessimistic.matches_current_ruby?).to be true
      end
    end
  end

  describe "real-world scenario simulation" do
    # Simulates a common scenario: a gem that was released before Ruby 3.0
    # and has required_ruby_version = ">= 2.5, < 3.0"

    it "allows installing legacy gems on newer Ruby with the directive" do
      # This tests the full flow without actually running bundle install

      # 1. Create a spec like one from a legacy gem
      legacy_spec = Gem::Specification.new do |s|
        s.name = "legacy_gem"
        s.version = "2.0.0"
        s.required_ruby_version = [">= 2.5.0", "< 3.0.0"]
      end

      # 2. Without the plugin, it would be rejected on Ruby 3.x
      skip "Test requires Ruby >= 3.0" if Gem.ruby_version < Gem::Version.new("3.0.0")

      definition_disabled = instance_double(Bundler::Definition, ignore_ruby_upper_bound: false)
      allow(Bundler).to receive(:definition).and_return(definition_disabled)
      expect(legacy_spec.matches_current_ruby?).to be false

      # 3. With the plugin enabled, it passes
      definition_enabled = instance_double(Bundler::Definition, ignore_ruby_upper_bound: true)
      allow(Bundler).to receive(:definition).and_return(definition_enabled)
      expect(legacy_spec.matches_current_ruby?).to be true
    end

    it "preserves lower bound checking" do
      # Even with the plugin, if Ruby version is too OLD, it should fail
      ancient_gem = Gem::Specification.new do |s|
        s.name = "future_gem"
        s.version = "1.0.0"
        s.required_ruby_version = ">= 99.0.0" # Requires future Ruby
      end

      definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: true)
      allow(Bundler).to receive(:definition).and_return(definition)

      # Lower bound is still enforced - current Ruby is not >= 99.0.0
      expect(ancient_gem.matches_current_ruby?).to be false
    end
  end

  describe "resolver filtering integration" do
    # Test that Ruby\0 dependencies in the resolver are filtered correctly

    it "filters Ruby upper bounds in dependency resolution" do
      definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: true)
      allow(Bundler).to receive(:definition).and_return(definition)

      filter_module = Module.new do
        include Bundler::IgnoreRubyUpperBound::ResolverPatch

        def filter_ruby_upper_bounds(deps)
          super
        end
      end

      filter = Object.new.extend(filter_module)

      # Simulate a dependency like what the resolver sees
      ruby_dep = Gem::Dependency.new("Ruby\0", [">= 2.7", "< 3.3"])
      other_dep = Gem::Dependency.new("rails", ">= 7.0")

      filtered = filter.filter_ruby_upper_bounds([ruby_dep, other_dep])

      # Ruby dependency should have upper bound removed
      ruby_filtered = filtered.find { |d| d.name == "Ruby\0" }
      expect(ruby_filtered.requirement).to eq(Gem::Requirement.new(">= 2.7"))

      # Other dependencies unchanged
      rails_filtered = filtered.find { |d| d.name == "rails" }
      expect(rails_filtered.requirement).to eq(Gem::Requirement.new(">= 7.0"))
    end
  end
end

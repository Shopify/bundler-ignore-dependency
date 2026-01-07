# frozen_string_literal: true

RSpec.describe Bundler::IgnoreRubyUpperBound::MatchMetadataPatch do
  def with_ignored_dependencies(deps)
    definition = instance_double(Bundler::Definition, ignored_dependencies: deps)
    allow(Bundler).to receive(:definition).and_return(definition)
  end

  def spec_with_requirements(ruby: nil, rubygems: nil)
    Gem::Specification.new do |s|
      s.name = "test_gem"
      s.version = "1.0.0"
      s.required_ruby_version = ruby if ruby
      s.required_rubygems_version = rubygems if rubygems
    end
  end

  describe "#matches_current_ruby?" do
    context "when :ruby is completely ignored" do
      before { with_ignored_dependencies({ ruby: :complete }) }

      it "returns true regardless of requirement" do
        spec = spec_with_requirements(ruby: ">= 99.0.0")
        expect(spec.matches_current_ruby?).to be true
      end
    end

    context "when :ruby upper bound is ignored" do
      before { with_ignored_dependencies({ ruby: :upper }) }

      it "returns true when only upper bound excludes current Ruby" do
        skip "Test requires Ruby >= 3.0" if Gem.ruby_version < Gem::Version.new("3.0.0")

        spec = spec_with_requirements(ruby: [">= 2.7", "< 3.0"])
        expect(spec.matches_current_ruby?).to be true
      end

      it "returns false when lower bound excludes current Ruby" do
        spec = spec_with_requirements(ruby: ">= 99.0.0")
        expect(spec.matches_current_ruby?).to be false
      end
    end

    context "when :ruby is not ignored" do
      before { with_ignored_dependencies({}) }

      it "returns false when requirement excludes current Ruby" do
        skip "Test requires Ruby >= 3.0" if Gem.ruby_version < Gem::Version.new("3.0.0")

        spec = spec_with_requirements(ruby: [">= 2.7", "< 3.0"])
        expect(spec.matches_current_ruby?).to be false
      end

      it "returns true when requirement matches current Ruby" do
        spec = spec_with_requirements(ruby: ">= 2.7")
        expect(spec.matches_current_ruby?).to be true
      end
    end
  end

  describe "#matches_current_rubygems?" do
    context "when :rubygems is completely ignored" do
      before { with_ignored_dependencies({ rubygems: :complete }) }

      it "returns true regardless of requirement" do
        spec = spec_with_requirements(rubygems: ">= 99.0.0")
        expect(spec.matches_current_rubygems?).to be true
      end
    end

    context "when :rubygems upper bound is ignored" do
      before { with_ignored_dependencies({ rubygems: :upper }) }

      it "removes upper bound from requirement" do
        # Create a requirement that would fail without the patch
        current_version = Gem.rubygems_version
        upper_bound = Gem::Version.new("#{current_version.segments[0]}.0.0")

        spec = spec_with_requirements(rubygems: [">= 1.0", "< #{upper_bound}"])

        # With upper bound ignored, this should pass if current >= 1.0
        if current_version >= Gem::Version.new("1.0")
          expect(spec.matches_current_rubygems?).to be true
        end
      end
    end

    context "when :rubygems is not ignored" do
      before { with_ignored_dependencies({}) }

      it "returns true when requirement matches current RubyGems" do
        spec = spec_with_requirements(rubygems: ">= 1.0")
        expect(spec.matches_current_rubygems?).to be true
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Bundler::IgnoreRubyUpperBound::MatchMetadataPatch do
  # MatchMetadata is a module included in Gem::Specification
  # We test via Gem::Specification which includes the patched module

  def spec_with_ruby_requirement(requirement)
    Gem::Specification.new do |s|
      s.name = "test_gem"
      s.version = "1.0.0"
      s.required_ruby_version = requirement if requirement
    end
  end

  describe "#matches_current_ruby?" do
    context "when ignore_ruby_upper_bound is disabled" do
      before do
        definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: false)
        allow(Bundler).to receive(:definition).and_return(definition)
      end

      context "when gem has no ruby requirement" do
        let(:spec) { spec_with_ruby_requirement(nil) }

        it "returns true" do
          expect(spec.matches_current_ruby?).to be true
        end
      end

      context "when gem requirement matches current ruby" do
        let(:spec) { spec_with_ruby_requirement(">= 2.7") }

        it "returns true" do
          expect(spec.matches_current_ruby?).to be true
        end
      end

      context "when gem has upper bound excluding current ruby" do
        # Assuming current Ruby is >= 3.1 (per gemspec requirement)
        let(:spec) { spec_with_ruby_requirement([">= 2.7", "< 3.0"]) }

        it "returns false" do
          expect(spec.matches_current_ruby?).to be false
        end
      end
    end

    context "when ignore_ruby_upper_bound is enabled" do
      before do
        definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: true)
        allow(Bundler).to receive(:definition).and_return(definition)
      end

      context "when gem has no ruby requirement" do
        let(:spec) { spec_with_ruby_requirement(nil) }

        it "returns true" do
          expect(spec.matches_current_ruby?).to be true
        end
      end

      context "when gem requirement matches current ruby" do
        let(:spec) { spec_with_ruby_requirement(">= 2.7") }

        it "returns true" do
          expect(spec.matches_current_ruby?).to be true
        end
      end

      context "when gem has upper bound excluding current ruby" do
        # With ignore_ruby_upper_bound enabled, the upper bound is removed
        let(:spec) { spec_with_ruby_requirement([">= 2.7", "< 3.0"]) }

        it "returns true by ignoring the upper bound" do
          expect(spec.matches_current_ruby?).to be true
        end
      end

      context "when gem has pessimistic constraint" do
        let(:spec) { spec_with_ruby_requirement("~> 2.7") }

        it "returns true by converting to >= only" do
          expect(spec.matches_current_ruby?).to be true
        end
      end
    end

    context "when no definition exists" do
      before do
        allow(Bundler).to receive(:definition).and_return(nil)
      end

      context "when gem has upper bound excluding current ruby" do
        let(:spec) { spec_with_ruby_requirement([">= 2.7", "< 3.0"]) }

        it "uses original requirement and returns false" do
          expect(spec.matches_current_ruby?).to be false
        end
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Bundler::IgnoreRubyUpperBound do
  describe ".remove_upper_bounds" do
    subject(:filtered) { described_class.remove_upper_bounds(requirement) }

    context "when requirement is nil" do
      let(:requirement) { nil }

      it "returns default requirement" do
        expect(filtered).to eq(Gem::Requirement.default)
      end
    end

    context "when requirement is empty" do
      let(:requirement) { Gem::Requirement.new([]) }

      it "returns default requirement" do
        expect(filtered).to eq(Gem::Requirement.default)
      end
    end

    context "with only lower bounds" do
      context "with >= operator" do
        let(:requirement) { Gem::Requirement.new(">= 2.7") }

        it "keeps the lower bound" do
          expect(filtered).to eq(Gem::Requirement.new(">= 2.7"))
        end
      end

      context "with > operator" do
        let(:requirement) { Gem::Requirement.new("> 2.7") }

        it "keeps the lower bound" do
          expect(filtered).to eq(Gem::Requirement.new("> 2.7"))
        end
      end

      context "with = operator" do
        let(:requirement) { Gem::Requirement.new("= 3.0") }

        it "keeps the exact version" do
          expect(filtered).to eq(Gem::Requirement.new("= 3.0"))
        end
      end

      context "with multiple lower bounds" do
        let(:requirement) { Gem::Requirement.new([">= 2.7", "> 2.6"]) }

        it "keeps all lower bounds" do
          expect(filtered.requirements).to contain_exactly(
            [">=", Gem::Version.new("2.7")],
            [">", Gem::Version.new("2.6")]
          )
        end
      end
    end

    context "with only upper bounds" do
      context "with < operator" do
        let(:requirement) { Gem::Requirement.new("< 4.0") }

        it "returns default requirement" do
          expect(filtered).to eq(Gem::Requirement.default)
        end
      end

      context "with <= operator" do
        let(:requirement) { Gem::Requirement.new("<= 3.2") }

        it "returns default requirement" do
          expect(filtered).to eq(Gem::Requirement.default)
        end
      end
    end

    context "with mixed bounds" do
      context "with >= and <" do
        let(:requirement) { Gem::Requirement.new([">= 2.7", "< 3.1"]) }

        it "removes upper bound and keeps lower bound" do
          expect(filtered).to eq(Gem::Requirement.new(">= 2.7"))
        end
      end

      context "with >= and <=" do
        let(:requirement) { Gem::Requirement.new([">= 2.7", "<= 3.2"]) }

        it "removes upper bound and keeps lower bound" do
          expect(filtered).to eq(Gem::Requirement.new(">= 2.7"))
        end
      end

      context "with > and <" do
        let(:requirement) { Gem::Requirement.new(["> 2.6", "< 4.0"]) }

        it "removes upper bound and keeps lower bound" do
          expect(filtered).to eq(Gem::Requirement.new("> 2.6"))
        end
      end
    end

    context "with pessimistic operator ~>" do
      context "with ~> alone" do
        let(:requirement) { Gem::Requirement.new("~> 2.7") }

        it "converts to >= equivalent" do
          expect(filtered).to eq(Gem::Requirement.new(">= 2.7"))
        end
      end

      context "with ~> and patch version" do
        let(:requirement) { Gem::Requirement.new("~> 2.7.0") }

        it "converts to >= equivalent" do
          expect(filtered).to eq(Gem::Requirement.new(">= 2.7.0"))
        end
      end

      context "with ~> and explicit upper bound" do
        let(:requirement) { Gem::Requirement.new(["~> 2.7", "< 3.0"]) }

        it "converts ~> to >= and removes <" do
          expect(filtered).to eq(Gem::Requirement.new(">= 2.7"))
        end
      end
    end

    context "with complex requirements" do
      context "with multiple mixed constraints" do
        let(:requirement) { Gem::Requirement.new([">= 2.5", "< 4.0", "> 2.4"]) }

        it "keeps only lower bounds" do
          expect(filtered.requirements).to contain_exactly(
            [">=", Gem::Version.new("2.5")],
            [">", Gem::Version.new("2.4")]
          )
        end
      end

      context "typical Ruby version constraint from a gem" do
        let(:requirement) { Gem::Requirement.new([">= 2.7.0", "< 3.3.0"]) }

        it "removes upper bound" do
          expect(filtered).to eq(Gem::Requirement.new(">= 2.7.0"))
        end

        it "allows newer Ruby versions" do
          expect(filtered.satisfied_by?(Gem::Version.new("3.4.0"))).to be true
        end
      end
    end

    describe "version satisfaction" do
      let(:ruby_34) { Gem::Version.new("3.4.0") }
      let(:ruby_27) { Gem::Version.new("2.7.0") }

      context "when original requirement excludes Ruby 3.4" do
        let(:requirement) { Gem::Requirement.new([">= 2.7", "< 3.3"]) }

        it "original requirement does not satisfy Ruby 3.4" do
          expect(requirement.satisfied_by?(ruby_34)).to be false
        end

        it "filtered requirement satisfies Ruby 3.4" do
          expect(filtered.satisfied_by?(ruby_34)).to be true
        end
      end

      context "when original requirement includes all versions" do
        let(:requirement) { Gem::Requirement.new(">= 2.7") }

        it "both requirements satisfy Ruby 3.4" do
          expect(requirement.satisfied_by?(ruby_34)).to be true
          expect(filtered.satisfied_by?(ruby_34)).to be true
        end
      end
    end
  end
end

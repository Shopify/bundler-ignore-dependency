# frozen_string_literal: true

RSpec.describe Bundler::IgnoreRubyUpperBound do
  def with_ignored_dependencies(deps)
    definition = instance_double(Bundler::Definition, ignored_dependencies: deps)
    allow(Bundler).to receive(:definition).and_return(definition)
    yield
  end

  describe ".ignored_dependencies" do
    it "returns empty hash when no definition" do
      allow(Bundler).to receive(:definition).and_return(nil)
      expect(described_class.ignored_dependencies).to eq({})
    end

    it "returns ignored dependencies from definition" do
      with_ignored_dependencies({ ruby: :upper }) do
        expect(described_class.ignored_dependencies).to eq({ ruby: :upper })
      end
    end
  end

  describe ".ignore_type_for" do
    it "returns nil for non-ignored dependency" do
      with_ignored_dependencies({}) do
        expect(described_class.ignore_type_for(:ruby)).to be_nil
      end
    end

    it "returns the ignore type for ignored dependency" do
      with_ignored_dependencies({ ruby: :upper, "nokogiri" => :complete }) do
        expect(described_class.ignore_type_for(:ruby)).to eq(:upper)
        expect(described_class.ignore_type_for("nokogiri")).to eq(:complete)
      end
    end
  end

  describe ".completely_ignored?" do
    it "returns true when type is :complete" do
      with_ignored_dependencies({ ruby: :complete }) do
        expect(described_class.completely_ignored?(:ruby)).to be true
      end
    end

    it "returns false when type is :upper" do
      with_ignored_dependencies({ ruby: :upper }) do
        expect(described_class.completely_ignored?(:ruby)).to be false
      end
    end

    it "returns false when not ignored" do
      with_ignored_dependencies({}) do
        expect(described_class.completely_ignored?(:ruby)).to be false
      end
    end
  end

  describe ".upper_bound_ignored?" do
    it "returns true when type is :upper" do
      with_ignored_dependencies({ ruby: :upper }) do
        expect(described_class.upper_bound_ignored?(:ruby)).to be true
      end
    end

    it "returns false when type is :complete" do
      with_ignored_dependencies({ ruby: :complete }) do
        expect(described_class.upper_bound_ignored?(:ruby)).to be false
      end
    end

    it "returns false when not ignored" do
      with_ignored_dependencies({}) do
        expect(described_class.upper_bound_ignored?(:ruby)).to be false
      end
    end
  end

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
    end

    context "with pessimistic operator ~>" do
      context "with ~> alone" do
        let(:requirement) { Gem::Requirement.new("~> 2.7") }

        it "converts to >= equivalent" do
          expect(filtered).to eq(Gem::Requirement.new(">= 2.7"))
        end
      end
    end
  end

  describe ".apply_ignore_rule" do
    let(:requirement) { Gem::Requirement.new([">= 2.7", "< 3.3"]) }

    it "returns default requirement when completely ignored" do
      with_ignored_dependencies({ ruby: :complete }) do
        result = described_class.apply_ignore_rule(requirement, :ruby)
        expect(result).to eq(Gem::Requirement.default)
      end
    end

    it "removes upper bounds when upper bound ignored" do
      with_ignored_dependencies({ ruby: :upper }) do
        result = described_class.apply_ignore_rule(requirement, :ruby)
        expect(result).to eq(Gem::Requirement.new(">= 2.7"))
      end
    end

    it "returns original requirement when not ignored" do
      with_ignored_dependencies({}) do
        result = described_class.apply_ignore_rule(requirement, :ruby)
        expect(result).to eq(requirement)
      end
    end
  end
end

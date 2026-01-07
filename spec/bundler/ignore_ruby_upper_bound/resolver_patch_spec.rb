# frozen_string_literal: true

RSpec.describe Bundler::IgnoreRubyUpperBound::ResolverPatch do
  def with_ignored_dependencies(deps)
    definition = instance_double(Bundler::Definition, ignored_dependencies: deps)
    allow(Bundler).to receive(:definition).and_return(definition)
  end

  describe "#filter_ignored_dependencies (private)" do
    let(:resolver_class) do
      Class.new do
        include Bundler::IgnoreRubyUpperBound::ResolverPatch

        public :filter_ignored_dependencies
      end
    end

    let(:resolver) { resolver_class.new }

    def ruby_dependency(requirement)
      Gem::Dependency.new("Ruby\0", requirement)
    end

    def rubygems_dependency(requirement)
      Gem::Dependency.new("RubyGems\0", requirement)
    end

    def gem_dependency(name, requirement)
      Gem::Dependency.new(name, requirement)
    end

    context "when no dependencies are ignored" do
      before { with_ignored_dependencies({}) }

      it "returns dependencies unchanged" do
        deps = [ruby_dependency(">= 2.7"), gem_dependency("rails", ">= 7.0")]
        result = resolver.filter_ignored_dependencies(deps)
        expect(result).to eq(deps)
      end
    end

    context "when :ruby is completely ignored" do
      before { with_ignored_dependencies({ ruby: :complete }) }

      it "removes Ruby dependency entirely" do
        deps = [
          ruby_dependency([">= 2.7", "< 3.3"]),
          gem_dependency("rails", ">= 7.0")
        ]

        result = resolver.filter_ignored_dependencies(deps)

        expect(result.map(&:name)).to eq(["rails"])
      end
    end

    context "when :ruby upper bound is ignored" do
      before { with_ignored_dependencies({ ruby: :upper }) }

      it "removes upper bounds from Ruby dependency" do
        deps = [ruby_dependency([">= 2.7", "< 3.3"])]

        result = resolver.filter_ignored_dependencies(deps)

        expect(result.first.name).to eq("Ruby\0")
        expect(result.first.requirement).to eq(Gem::Requirement.new(">= 2.7"))
      end
    end

    context "when :rubygems is completely ignored" do
      before { with_ignored_dependencies({ rubygems: :complete }) }

      it "removes RubyGems dependency entirely" do
        deps = [
          rubygems_dependency(">= 3.0"),
          gem_dependency("rails", ">= 7.0")
        ]

        result = resolver.filter_ignored_dependencies(deps)

        expect(result.map(&:name)).to eq(["rails"])
      end
    end

    context "when gem is completely ignored" do
      before { with_ignored_dependencies({ "nokogiri" => :complete }) }

      it "removes the gem dependency entirely" do
        deps = [
          gem_dependency("nokogiri", ">= 1.0"),
          gem_dependency("rails", ">= 7.0")
        ]

        result = resolver.filter_ignored_dependencies(deps)

        expect(result.map(&:name)).to eq(["rails"])
      end
    end

    context "when gem upper bound is ignored" do
      before { with_ignored_dependencies({ "nokogiri" => :upper }) }

      it "removes upper bounds from gem dependency" do
        deps = [gem_dependency("nokogiri", [">= 1.0", "< 2.0"])]

        result = resolver.filter_ignored_dependencies(deps)

        expect(result.first.name).to eq("nokogiri")
        expect(result.first.requirement).to eq(Gem::Requirement.new(">= 1.0"))
      end
    end

    context "with multiple ignored dependencies" do
      before do
        with_ignored_dependencies({
          ruby: :upper,
          rubygems: :complete,
          "nokogiri" => :complete
        })
      end

      it "applies all ignore rules" do
        deps = [
          ruby_dependency([">= 2.7", "< 3.3"]),
          rubygems_dependency(">= 3.0"),
          gem_dependency("nokogiri", ">= 1.0"),
          gem_dependency("rails", ">= 7.0")
        ]

        result = resolver.filter_ignored_dependencies(deps)

        # Ruby: upper bounds removed
        ruby_dep = result.find { |d| d.name == "Ruby\0" }
        expect(ruby_dep.requirement).to eq(Gem::Requirement.new(">= 2.7"))

        # RubyGems: completely removed
        expect(result.none? { |d| d.name == "RubyGems\0" }).to be true

        # nokogiri: completely removed
        expect(result.none? { |d| d.name == "nokogiri" }).to be true

        # rails: unchanged
        rails_dep = result.find { |d| d.name == "rails" }
        expect(rails_dep.requirement).to eq(Gem::Requirement.new(">= 7.0"))
      end
    end
  end
end

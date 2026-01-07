# frozen_string_literal: true

RSpec.describe Bundler::IgnoreRubyUpperBound::ResolverPatch do
  describe "#filter_ruby_upper_bounds (private)" do
    let(:filter_class) do
      Class.new do
        include Bundler::IgnoreRubyUpperBound::ResolverPatch

        def filter_ruby_upper_bounds(deps)
          super
        end
      end
    end

    let(:filter) { filter_class.new }

    def ruby_dependency(requirement)
      Gem::Dependency.new("Ruby\0", requirement)
    end

    def regular_dependency(name, requirement)
      Gem::Dependency.new(name, requirement)
    end

    before do
      definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: true)
      allow(Bundler).to receive(:definition).and_return(definition)
    end

    it "filters upper bounds from Ruby dependencies" do
      deps = [ruby_dependency([">= 2.7", "< 3.3"])]

      result = filter.filter_ruby_upper_bounds(deps)

      expect(result.first.name).to eq("Ruby\0")
      expect(result.first.requirement).to eq(Gem::Requirement.new(">= 2.7"))
    end

    it "preserves non-Ruby dependencies unchanged" do
      deps = [regular_dependency("rails", ">= 7.0")]

      result = filter.filter_ruby_upper_bounds(deps)

      expect(result.first.name).to eq("rails")
      expect(result.first.requirement).to eq(Gem::Requirement.new(">= 7.0"))
    end

    it "handles mixed dependencies" do
      deps = [
        ruby_dependency([">= 2.7", "< 3.3"]),
        regular_dependency("rails", [">= 7.0", "< 8.0"]),
        ruby_dependency("~> 3.0")
      ]

      result = filter.filter_ruby_upper_bounds(deps)

      ruby_deps = result.select { |d| d.name == "Ruby\0" }
      expect(ruby_deps[0].requirement).to eq(Gem::Requirement.new(">= 2.7"))
      expect(ruby_deps[1].requirement).to eq(Gem::Requirement.new(">= 3.0"))

      rails_dep = result.find { |d| d.name == "rails" }
      expect(rails_dep.requirement).to eq(Gem::Requirement.new([">= 7.0", "< 8.0"]))
    end

    it "returns empty array for empty input" do
      result = filter.filter_ruby_upper_bounds([])

      expect(result).to eq([])
    end

    it "handles pessimistic Ruby constraints" do
      deps = [ruby_dependency("~> 2.7.0")]

      result = filter.filter_ruby_upper_bounds(deps)

      expect(result.first.requirement).to eq(Gem::Requirement.new(">= 2.7.0"))
    end

    context "when ignore_ruby_upper_bound is disabled" do
      before do
        definition = instance_double(Bundler::Definition, ignore_ruby_upper_bound: false)
        allow(Bundler).to receive(:definition).and_return(definition)
      end

      it "returns dependencies unchanged" do
        deps = [ruby_dependency([">= 2.7", "< 3.3"])]

        result = filter.filter_ruby_upper_bounds(deps)

        expect(result).to eq(deps)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Bundler::IgnoreDependency::LazySpecificationPatch do
  def with_ignored_dependencies(deps)
    definition = instance_double(Bundler::Definition, ignored_dependencies: deps)
    allow(Bundler).to receive(:definition).and_return(definition)
    # Reset the memoized cache
    Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
  end

  def gem_dependency(name, requirement = ">= 0")
    Gem::Dependency.new(name, requirement)
  end

  def mock_lazy_spec(name, version, dependencies)
    lazy_spec = Bundler::LazySpecification.new(name, Gem::Version.new(version), nil)
    lazy_spec.dependencies = dependencies.dup
    lazy_spec
  end

  describe "#filter_ignored_dependencies (private)" do
    # Create a test class that includes the patch module to test the private method
    let(:patch_class) do
      Class.new do
        extend Bundler::IgnoreDependency::LazySpecificationPatch

        class << self
          public :filter_ignored_dependencies
        end
      end
    end

    context "when no gems are completely ignored" do
      before { with_ignored_dependencies({}) }

      it "returns lazy spec with dependencies unchanged" do
        deps = [gem_dependency("activesupport"), gem_dependency("nokogiri")]
        lazy_spec = mock_lazy_spec("rails", "7.0.0", deps)

        result = patch_class.filter_ignored_dependencies(lazy_spec)

        expect(result.dependencies.map(&:name)).to eq(["activesupport", "nokogiri"])
      end
    end

    context "when a gem is completely ignored" do
      before { with_ignored_dependencies({ "activerecord" => :complete }) }

      it "filters out the ignored gem from dependencies" do
        deps = [
          gem_dependency("activesupport"),
          gem_dependency("activerecord"),
          gem_dependency("nokogiri")
        ]
        lazy_spec = mock_lazy_spec("rails", "7.0.0", deps)

        result = patch_class.filter_ignored_dependencies(lazy_spec)

        expect(result.dependencies.map(&:name)).to eq(["activesupport", "nokogiri"])
      end
    end

    context "when multiple gems are completely ignored" do
      before do
        with_ignored_dependencies({
          "activerecord" => :complete,
          "nokogiri" => :complete
        })
      end

      it "filters out all ignored gems from dependencies" do
        deps = [
          gem_dependency("activesupport"),
          gem_dependency("activerecord"),
          gem_dependency("nokogiri"),
          gem_dependency("rack")
        ]
        lazy_spec = mock_lazy_spec("rails", "7.0.0", deps)

        result = patch_class.filter_ignored_dependencies(lazy_spec)

        expect(result.dependencies.map(&:name)).to eq(["activesupport", "rack"])
      end
    end

    context "when gem has upper bound ignored (not complete)" do
      before { with_ignored_dependencies({ "nokogiri" => :upper }) }

      it "does not filter out the gem (only complete ignores filter)" do
        deps = [gem_dependency("activesupport"), gem_dependency("nokogiri")]
        lazy_spec = mock_lazy_spec("rails", "7.0.0", deps)

        result = patch_class.filter_ignored_dependencies(lazy_spec)

        expect(result.dependencies.map(&:name)).to eq(["activesupport", "nokogiri"])
      end
    end
  end
end

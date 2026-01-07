# frozen_string_literal: true

RSpec.describe Bundler::IgnoreDependency::SharedHelpersPatch do
  def with_ignored_dependencies(deps)
    definition = instance_double(Bundler::Definition, ignored_dependencies: deps)
    allow(Bundler).to receive(:definition).and_return(definition)
    # Reset the memoized cache
    Bundler::IgnoreDependency.instance_variable_set(:@completely_ignored_gem_names, nil)
  end

  def gem_dependency(name, requirement = ">= 0")
    Gem::Dependency.new(name, requirement)
  end

  def mock_spec(name, version)
    instance_double(Gem::Specification, full_name: "#{name}-#{version}", name: name, remote: nil)
  end

  describe ".ensure_same_dependencies" do
    context "when no gems are completely ignored" do
      before { with_ignored_dependencies({}) }

      it "raises error when new deps have extra dependencies" do
        spec = mock_spec("rails", "7.0.0")
        old_deps = [gem_dependency("activesupport", "= 7.0.0")]
        new_deps = [
          gem_dependency("activesupport", "= 7.0.0"),
          gem_dependency("activerecord", "= 7.0.0")
        ]

        expect {
          Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
        }.to raise_error(Bundler::APIResponseMismatchError, /revealed dependencies not in the API/)
      end

      it "does not raise when dependencies match" do
        spec = mock_spec("rails", "7.0.0")
        old_deps = [gem_dependency("activesupport", "= 7.0.0")]
        new_deps = [gem_dependency("activesupport", "= 7.0.0")]

        expect {
          Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
        }.not_to raise_error
      end
    end

    context "when a gem is completely ignored" do
      before { with_ignored_dependencies({ "activerecord" => :complete }) }

      it "does not raise when ignored gem is in new deps but not old deps" do
        spec = mock_spec("rails", "7.0.0")
        old_deps = [gem_dependency("activesupport", "= 7.0.0")]
        new_deps = [
          gem_dependency("activesupport", "= 7.0.0"),
          gem_dependency("activerecord", "= 7.0.0")
        ]

        expect {
          Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
        }.not_to raise_error
      end

      it "still raises for non-ignored extra dependencies" do
        spec = mock_spec("rails", "7.0.0")
        old_deps = [gem_dependency("activesupport", "= 7.0.0")]
        new_deps = [
          gem_dependency("activesupport", "= 7.0.0"),
          gem_dependency("activerecord", "= 7.0.0"),
          gem_dependency("nokogiri", "= 1.0.0")
        ]

        expect {
          Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
        }.to raise_error(Bundler::APIResponseMismatchError, /nokogiri/)
      end
    end

    context "when multiple gems are completely ignored" do
      before do
        with_ignored_dependencies({
          "activerecord" => :complete,
          "actionmailer" => :complete
        })
      end

      it "does not raise when all extra deps are ignored" do
        spec = mock_spec("rails", "7.0.0")
        old_deps = [gem_dependency("activesupport", "= 7.0.0")]
        new_deps = [
          gem_dependency("activesupport", "= 7.0.0"),
          gem_dependency("activerecord", "= 7.0.0"),
          gem_dependency("actionmailer", "= 7.0.0")
        ]

        expect {
          Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
        }.not_to raise_error
      end
    end

    context "when gem has upper bound ignored (not complete)" do
      before { with_ignored_dependencies({ "activerecord" => :upper }) }

      it "still raises because only complete ignores filter from validation" do
        spec = mock_spec("rails", "7.0.0")
        old_deps = [gem_dependency("activesupport", "= 7.0.0")]
        new_deps = [
          gem_dependency("activesupport", "= 7.0.0"),
          gem_dependency("activerecord", "= 7.0.0")
        ]

        expect {
          Bundler::SharedHelpers.ensure_same_dependencies(spec, old_deps, new_deps)
        }.to raise_error(Bundler::APIResponseMismatchError, /activerecord/)
      end
    end
  end
end

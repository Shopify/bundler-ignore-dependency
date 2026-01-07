# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe "ignore_dependency! integration" do
  def with_ignored_dependencies(deps)
    definition = instance_double(Bundler::Definition, ignored_dependencies: deps)
    allow(Bundler).to receive(:definition).and_return(definition)
  end

  describe "Gemfile DSL integration" do
    it "can ignore :ruby completely with normalized key" do
      dsl = Bundler::Dsl.new
      dsl.ignore_dependency!(:ruby)

      expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({ "Ruby\0" => :complete })
    end

    it "can ignore :ruby upper bounds only with normalized key" do
      dsl = Bundler::Dsl.new
      dsl.ignore_dependency!(:ruby, type: :upper)

      expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({ "Ruby\0" => :upper })
    end

    it "can ignore multiple dependencies with normalized keys" do
      dsl = Bundler::Dsl.new
      dsl.ignore_dependency!(:ruby, type: :upper)
      dsl.ignore_dependency!(:rubygems)
      dsl.ignore_dependency!("nokogiri")

      expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({
        "Ruby\0" => :upper,
        "RubyGems\0" => :complete,
        "nokogiri" => :complete
      })
    end

    it "propagates settings through to Definition with normalized keys" do
      Dir.mktmpdir do |dir|
        gemfile_path = File.join(dir, "Gemfile")
        lockfile_path = File.join(dir, "Gemfile.lock")

        File.write(gemfile_path, <<~GEMFILE)
          source "https://rubygems.org"
          ignore_dependency! :ruby, type: :upper
        GEMFILE

        allow(Bundler::SharedHelpers).to receive(:pwd).and_return(dir)

        definition = Bundler::Definition.build(gemfile_path, lockfile_path, {})

        expect(definition.ignored_dependencies).to eq({ "Ruby\0" => :upper })
      end
    end
  end

  describe "MatchMetadata integration" do
    let(:spec_with_upper_bound) do
      Gem::Specification.new do |s|
        s.name = "test_gem"
        s.version = "1.0.0"
        s.required_ruby_version = [">= 2.7.0", "< 3.0.0"]
      end
    end

    context "on Ruby 3.x" do
      before do
        skip "Test requires Ruby >= 3.0" if Gem.ruby_version < Gem::Version.new("3.0.0")
      end

      it "rejects gem when Ruby is not ignored" do
        with_ignored_dependencies({})
        expect(spec_with_upper_bound.matches_current_ruby?).to be false
      end

      it "accepts gem when Ruby is completely ignored" do
        with_ignored_dependencies({ "Ruby\0" => :complete })
        expect(spec_with_upper_bound.matches_current_ruby?).to be true
      end

      it "accepts gem when Ruby upper bound is ignored" do
        with_ignored_dependencies({ "Ruby\0" => :upper })
        expect(spec_with_upper_bound.matches_current_ruby?).to be true
      end
    end
  end

  describe "real-world scenario simulation" do
    it "allows legacy gem with ignore_dependency! :ruby, type: :upper" do
      skip "Test requires Ruby >= 3.0" if Gem.ruby_version < Gem::Version.new("3.0.0")

      legacy_spec = Gem::Specification.new do |s|
        s.name = "legacy_gem"
        s.version = "2.0.0"
        s.required_ruby_version = [">= 2.5.0", "< 3.0.0"]
      end

      # Without ignore rule
      with_ignored_dependencies({})
      expect(legacy_spec.matches_current_ruby?).to be false

      # With upper bound ignored (equivalent to old ignore_ruby_upper_bound!)
      with_ignored_dependencies({ "Ruby\0" => :upper })
      expect(legacy_spec.matches_current_ruby?).to be true
    end

    it "completely ignores Ruby requirement with ignore_dependency! :ruby" do
      future_gem = Gem::Specification.new do |s|
        s.name = "future_gem"
        s.version = "1.0.0"
        s.required_ruby_version = ">= 99.0.0"
      end

      # Without ignore rule - fails due to lower bound
      with_ignored_dependencies({})
      expect(future_gem.matches_current_ruby?).to be false

      # With :upper only - still fails due to lower bound
      with_ignored_dependencies({ "Ruby\0" => :upper })
      expect(future_gem.matches_current_ruby?).to be false

      # With :complete - passes regardless
      with_ignored_dependencies({ "Ruby\0" => :complete })
      expect(future_gem.matches_current_ruby?).to be true
    end
  end

  describe "resolver filtering integration" do
    let(:resolver_class) do
      Class.new do
        include Bundler::IgnoreRubyUpperBound::ResolverPatch
        public :filter_ignored_dependencies
      end
    end

    let(:resolver) { resolver_class.new }

    it "filters dependencies according to ignore rules" do
      with_ignored_dependencies({
        "Ruby\0" => :upper,
        "nokogiri" => :complete
      })

      ruby_dep = Gem::Dependency.new("Ruby\0", [">= 2.7", "< 3.3"])
      nokogiri_dep = Gem::Dependency.new("nokogiri", ">= 1.0")
      rails_dep = Gem::Dependency.new("rails", ">= 7.0")

      result = resolver.filter_ignored_dependencies([ruby_dep, nokogiri_dep, rails_dep])

      # Ruby: upper bounds removed
      ruby_filtered = result.find { |d| d.name == "Ruby\0" }
      expect(ruby_filtered.requirement).to eq(Gem::Requirement.new(">= 2.7"))

      # nokogiri: completely removed
      expect(result.none? { |d| d.name == "nokogiri" }).to be true

      # rails: unchanged
      rails_filtered = result.find { |d| d.name == "rails" }
      expect(rails_filtered.requirement).to eq(Gem::Requirement.new(">= 7.0"))
    end
  end
end

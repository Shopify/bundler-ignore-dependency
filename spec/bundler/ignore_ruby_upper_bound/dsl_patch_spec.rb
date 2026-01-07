# frozen_string_literal: true

require "tmpdir"

RSpec.describe Bundler::IgnoreRubyUpperBound::DslPatch do
  let(:dsl) { Bundler::Dsl.new }

  describe "#ignore_ruby_upper_bound!" do
    it "defaults to false" do
      expect(dsl.instance_variable_get(:@ignore_ruby_upper_bound)).to be false
    end

    it "sets the flag to true" do
      dsl.ignore_ruby_upper_bound!
      expect(dsl.instance_variable_get(:@ignore_ruby_upper_bound)).to be true
    end
  end

  describe "#to_definition" do
    let(:lockfile) { Pathname.new(Dir.tmpdir).join("Gemfile.lock") }

    before do
      allow(Bundler::SharedHelpers).to receive(:pwd).and_return(Dir.tmpdir)
    end

    it "passes the flag to the definition when enabled" do
      dsl.source("https://rubygems.org")
      dsl.ignore_ruby_upper_bound!

      definition = dsl.to_definition(lockfile, {})

      expect(definition.ignore_ruby_upper_bound).to be true
    end

    it "passes false when not enabled" do
      dsl.source("https://rubygems.org")

      definition = dsl.to_definition(lockfile, {})

      expect(definition.ignore_ruby_upper_bound).to be false
    end
  end
end

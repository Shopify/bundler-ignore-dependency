# frozen_string_literal: true

RSpec.describe Bundler::IgnoreRubyUpperBound::DefinitionPatch do
  let(:definition) { Bundler::Definition.new(nil, [], Bundler::SourceList.new, {}) }

  describe "#ignore_ruby_upper_bound" do
    it "defaults to nil" do
      expect(definition.ignore_ruby_upper_bound).to be_nil
    end

    it "can be set to true" do
      definition.ignore_ruby_upper_bound = true
      expect(definition.ignore_ruby_upper_bound).to be true
    end

    it "can be set to false" do
      definition.ignore_ruby_upper_bound = false
      expect(definition.ignore_ruby_upper_bound).to be false
    end
  end
end

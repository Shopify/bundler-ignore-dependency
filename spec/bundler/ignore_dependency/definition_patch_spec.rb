# frozen_string_literal: true

RSpec.describe Bundler::IgnoreDependency::DefinitionPatch do
  let(:definition) { Bundler::Definition.new(nil, [], Bundler::SourceList.new, {}) }

  describe "#ignored_dependencies" do
    it "defaults to empty hash" do
      expect(definition.ignored_dependencies).to eq({})
    end

    it "can be set to a hash" do
      definition.ignored_dependencies = { ruby: :upper, "nokogiri" => :complete }
      expect(definition.ignored_dependencies).to eq({ ruby: :upper, "nokogiri" => :complete })
    end
  end
end

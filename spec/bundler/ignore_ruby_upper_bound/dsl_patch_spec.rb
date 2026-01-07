# frozen_string_literal: true

require "tmpdir"

RSpec.describe Bundler::IgnoreRubyUpperBound::DslPatch do
  let(:dsl) { Bundler::Dsl.new }

  describe "#ignore_dependency!" do
    it "defaults to empty hash" do
      expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({})
    end

    context "with :ruby" do
      it "stores :complete type by default" do
        dsl.ignore_dependency!(:ruby)
        expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({ ruby: :complete })
      end

      it "stores :upper type when specified" do
        dsl.ignore_dependency!(:ruby, type: :upper)
        expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({ ruby: :upper })
      end
    end

    context "with :rubygems" do
      it "stores :complete type by default" do
        dsl.ignore_dependency!(:rubygems)
        expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({ rubygems: :complete })
      end

      it "stores :upper type when specified" do
        dsl.ignore_dependency!(:rubygems, type: :upper)
        expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({ rubygems: :upper })
      end
    end

    context "with gem name string" do
      it "stores :complete type by default" do
        dsl.ignore_dependency!("nokogiri")
        expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({ "nokogiri" => :complete })
      end

      it "stores :upper type when specified" do
        dsl.ignore_dependency!("nokogiri", type: :upper)
        expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({ "nokogiri" => :upper })
      end
    end

    context "with multiple dependencies" do
      it "stores all ignored dependencies" do
        dsl.ignore_dependency!(:ruby, type: :upper)
        dsl.ignore_dependency!(:rubygems)
        dsl.ignore_dependency!("nokogiri")

        expect(dsl.instance_variable_get(:@ignored_dependencies)).to eq({
          ruby: :upper,
          rubygems: :complete,
          "nokogiri" => :complete
        })
      end
    end

    context "with invalid arguments" do
      it "raises error for invalid type" do
        expect { dsl.ignore_dependency!(:ruby, type: :invalid) }
          .to raise_error(ArgumentError, /type must be :complete or :upper/)
      end

      it "raises error for invalid dependency name" do
        expect { dsl.ignore_dependency!(123) }
          .to raise_error(ArgumentError, /dependency name must be/)
      end
    end
  end

  describe "#to_definition" do
    let(:lockfile) { Pathname.new(Dir.tmpdir).join("Gemfile.lock") }

    before do
      allow(Bundler::SharedHelpers).to receive(:pwd).and_return(Dir.tmpdir)
    end

    it "passes ignored dependencies to the definition" do
      dsl.source("https://rubygems.org")
      dsl.ignore_dependency!(:ruby, type: :upper)
      dsl.ignore_dependency!("nokogiri")

      definition = dsl.to_definition(lockfile, {})

      expect(definition.ignored_dependencies).to eq({
        ruby: :upper,
        "nokogiri" => :complete
      })
    end

    it "passes empty hash when no dependencies ignored" do
      dsl.source("https://rubygems.org")

      definition = dsl.to_definition(lockfile, {})

      expect(definition.ignored_dependencies).to eq({})
    end
  end
end

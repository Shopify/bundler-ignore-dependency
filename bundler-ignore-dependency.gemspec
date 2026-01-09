# frozen_string_literal: true

require_relative "lib/bundler/ignore_dependency/version"

Gem::Specification.new do |s|
  s.name        = "bundler-ignore-dependency"
  s.version     = Bundler::IgnoreDependency::VERSION
  s.summary     = "Bundler plugin to ignore dependency version constraints"
  s.description = "A Bundler plugin that adds an ignore_dependency! DSL method to allow ignoring version constraints on Ruby, RubyGems, or gem dependencies."
  s.authors     = ["Shopify"]
  s.homepage    = "https://github.com/Shopify/rubygems"
  s.license     = "MIT"

  s.files       = Dir["lib/**/*", "plugins.rb"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.1"
end

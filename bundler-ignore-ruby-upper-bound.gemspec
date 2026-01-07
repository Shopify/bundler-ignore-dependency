# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "bundler-ignore-ruby-upper-bound"
  s.version     = "0.1.0"
  s.summary     = "Bundler plugin to ignore Ruby version upper bounds"
  s.description = "A Bundler plugin that adds an ignore_ruby_upper_bound DSL method to allow installing gems that have Ruby version upper bounds that exclude the current Ruby version."
  s.authors     = ["Shopify"]
  s.homepage    = "https://github.com/Shopify/rubygems"
  s.license     = "MIT"

  s.files       = Dir["lib/**/*", "plugins.rb"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.1.0"

  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.0"
end

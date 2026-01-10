#!/usr/bin/env ruby
# frozen_string_literal: true

require "net/http"
require "json"

# Fetch all Bundler versions from rubygems.org API
response = Net::HTTP.get(URI("https://rubygems.org/info/bundler"))
versions = response.lines.map { |line| line.split(" ").first }.select { |v| v.match?(/^\d+\./) }

# Get the 2 latest major versions
latest_majors = versions.sort_by { |v| Gem::Version.new(v) }.reverse.map { |v| v.split(".").first }.uniq.take(2)

# Find the latest full version for each major version
latest_versions = latest_majors.map do |major|
  versions.select { |v| v.start_with?("#{major}.") }.max_by { |v| Gem::Version.new(v) }
end

# Output as JSON array
puts JSON.dump(latest_versions)

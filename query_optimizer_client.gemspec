# frozen_string_literal: true

require_relative "lib/query_optimizer_client/version"

Gem::Specification.new do |spec|
  spec.name = "QueryWise"
  spec.version = QueryOptimizerClient::VERSION
  spec.authors = ["Blair Lane"]
  spec.email = ["blairjacklane@gmail.com"]

  spec.summary = "Rails Database Query Optimizer Client"
  spec.description = "QueryWise is a lightweight, developer-friendly tool that helps Ruby on Rails teams detect, analyze, and fix inefficient database queries without needing heavy, expensive Application Performance Monitoring (APM) software."
  spec.homepage = "https://github.com/BlairLane22/QueryOptimizerAPI"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/BlairLane22/QueryOptimizerAPI"
  spec.metadata["changelog_uri"] = "https://github.com/BlairLane22/QueryOptimizerAPI/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/BlairLane22/QueryOptimizerAPI/blob/main/README.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "httparty", "~> 0.21"
  spec.add_dependency "activesupport", ">= 6.0"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "vcr", "~> 6.1"
  spec.add_development_dependency "rails", ">= 6.0"
  spec.add_development_dependency "sqlite3", "~> 1.4"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

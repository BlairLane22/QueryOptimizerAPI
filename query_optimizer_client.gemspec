# frozen_string_literal: true

require_relative "lib/query_optimizer_client/version"

Gem::Specification.new do |spec|
  spec.name = "QueryWise"
  spec.version = QueryOptimizerClient::VERSION
  spec.authors = ["Blair Lane"]
  spec.email = ["blairjacklane@gmail.com"]

  spec.summary = "QueryWise - Rails Database Query Optimizer"
  spec.description = "QueryWise is a lightweight, developer-friendly tool that helps Ruby on Rails teams detect, analyze, and fix inefficient database queries. Automatically detect N+1 queries, slow queries, and missing indexes without needing heavy, expensive Application Performance Monitoring (APM) software."
  spec.homepage = "https://github.com/BlairLane22/QueryOptimizerAPI"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/BlairLane22/QueryWise"
  spec.metadata["changelog_uri"] = "https://github.com/BlairLane22/QueryWise/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/BlairLane22/QueryWise/blob/main/README.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    Dir.glob("**/*", File::FNM_DOTMATCH).reject do |f|
      File.directory?(f) ||
      f.start_with?('.git/', 'tmp/', 'log/', 'spec/', 'test/', 'features/') ||
      f.match?(/\A\./) ||
      f.end_with?('.gem') ||
      f == 'Gemfile' ||
      f == 'Gemfile.lock' ||
      f == 'Rakefile' ||
      f.include?('docker') ||
      f.include?('scripts/') ||
      f.include?('docs/') ||
      f.start_with?('bin/') ||
      File.expand_path(f) == __FILE__
    end
  end
  
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "httparty", "~> 0.21"
  spec.add_dependency "activesupport", "~> 7.0"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "vcr", "~> 6.1"
  spec.add_development_dependency "rails", "~> 7.0"
  spec.add_development_dependency "sqlite3", "~> 1.4"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

# Publishing Query Optimizer Client to RubyGems

This guide walks you through publishing the Query Optimizer Client gem to RubyGems.

## Prerequisites

1. **RubyGems Account**: Create an account at [rubygems.org](https://rubygems.org)
2. **API Key**: Get your API key from your RubyGems profile
3. **Git Repository**: Set up a GitHub repository for the gem

## Pre-Publishing Checklist

### 1. Update Gem Information

Edit `query_optimizer_client.gemspec`:

```ruby
spec.authors = ["Your Name"]
spec.email = ["your.email@example.com"]
spec.homepage = "https://github.com/yourusername/query_optimizer_client"
spec.metadata["source_code_uri"] = "https://github.com/yourusername/query_optimizer_client"
```

### 2. Verify Version

Check `lib/query_optimizer_client/version.rb`:

```ruby
module QueryOptimizerClient
  VERSION = "0.1.0"  # Update as needed
end
```

### 3. Update Documentation

- [ ] Update `README.md` with correct GitHub URLs
- [ ] Update `CHANGELOG.md` with release notes
- [ ] Verify all code examples work
- [ ] Check that documentation is comprehensive

### 4. Run Tests

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run RuboCop for code style
bundle exec rubocop

# Fix any RuboCop issues
bundle exec rubocop -a
```

### 5. Test the Gem Locally

```bash
# Build the gem
gem build query_optimizer_client.gemspec

# Install locally to test
gem install ./query_optimizer_client-0.1.0.gem

# Test in a Rails app
cd /path/to/test/rails/app
echo 'gem "query_optimizer_client", path: "/path/to/gem"' >> Gemfile
bundle install
rails generate query_optimizer_client:install
```

## Publishing Steps

### 1. Set Up RubyGems Credentials

```bash
# Add your RubyGems API key
gem signin

# Or manually create credentials file
mkdir -p ~/.gem
echo "---
:rubygems_api_key: your_api_key_here" > ~/.gem/credentials
chmod 0600 ~/.gem/credentials
```

### 2. Build and Publish

```bash
# Build the gem
gem build query_optimizer_client.gemspec

# Push to RubyGems
gem push query_optimizer_client-0.1.0.gem
```

### 3. Verify Publication

- Check [rubygems.org/gems/query_optimizer_client](https://rubygems.org/gems/query_optimizer_client)
- Test installation: `gem install query_optimizer_client`

## Post-Publishing Tasks

### 1. Tag the Release

```bash
git tag v0.1.0
git push origin v0.1.0
```

### 2. Create GitHub Release

1. Go to your GitHub repository
2. Click "Releases" → "Create a new release"
3. Choose the tag you just created
4. Add release notes from CHANGELOG.md
5. Publish the release

### 3. Update Documentation

- [ ] Update README badges with correct gem version
- [ ] Update any documentation that references installation
- [ ] Consider creating a documentation website

## Gem Structure Overview

```
query_optimizer_client/
├── lib/
│   ├── query_optimizer_client.rb           # Main entry point
│   └── query_optimizer_client/
│       ├── version.rb                      # Version constant
│       ├── configuration.rb                # Configuration class
│       ├── client.rb                       # HTTP client
│       ├── middleware.rb                   # Rails middleware
│       ├── railtie.rb                      # Rails integration
│       ├── tasks.rake                      # Rake tasks
│       └── generators/
│           ├── install_generator.rb        # Rails generator
│           └── templates/
│               ├── initializer.rb          # Config template
│               ├── analysis_job.rb         # Job template
│               └── README                  # Post-install instructions
├── spec/                                   # Test files
├── query_optimizer_client.gemspec          # Gem specification
├── README.md                               # Main documentation
├── CHANGELOG.md                            # Version history
├── LICENSE.txt                             # MIT license
├── Gemfile                                 # Development dependencies
└── Rakefile                                # Build tasks
```

## Usage After Publishing

Once published, Rails developers can use your gem like this:

### Installation

```ruby
# Gemfile
gem 'query_optimizer_client'
```

```bash
bundle install
```

### Setup

```bash
rails generate query_optimizer_client:install
```

### Configuration

```bash
# .env
QUERY_OPTIMIZER_API_URL=http://localhost:3000/api/v1
QUERY_OPTIMIZER_API_KEY=your_api_key_here
QUERY_OPTIMIZER_ENABLED=true
```

### Usage

```ruby
# Manual analysis
queries = [
  { sql: "SELECT * FROM users", duration_ms: 50 }
]

result = QueryOptimizerClient.analyze_queries(queries)
puts "Score: #{result['data']['summary']['optimization_score']}%"

# CI integration
rails query_optimizer:ci[85]
```

## Maintenance

### Updating the Gem

1. Make changes to the code
2. Update version in `lib/query_optimizer_client/version.rb`
3. Update `CHANGELOG.md`
4. Run tests: `bundle exec rspec`
5. Build and publish: `gem build && gem push query_optimizer_client-x.x.x.gem`
6. Tag the release: `git tag vx.x.x && git push origin vx.x.x`

### Semantic Versioning

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backward compatible
- **PATCH** (0.0.1): Bug fixes, backward compatible

### Support

- Monitor GitHub issues
- Respond to user questions
- Keep dependencies updated
- Maintain compatibility with new Rails versions

## Security Considerations

- Never commit API keys or sensitive data
- Use `.gitignore` to exclude sensitive files
- Consider signing your gem releases
- Monitor for security vulnerabilities in dependencies

## Marketing and Community

- Announce on Ruby/Rails forums
- Write blog posts about the gem
- Present at Ruby meetups or conferences
- Engage with users on GitHub issues
- Consider creating video tutorials

## Example GitHub Actions for CI

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby-version: ['3.0', '3.1', '3.2']
        rails-version: ['6.1', '7.0', '7.1']
    
    steps:
    - uses: actions/checkout@v3
    - name: Set up Ruby ${{ matrix.ruby-version }}
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: ${{ matrix.ruby-version }}
        bundler-cache: true
    - name: Run tests
      run: bundle exec rspec
    - name: Run RuboCop
      run: bundle exec rubocop
```

This comprehensive guide should help you successfully publish and maintain the Query Optimizer Client gem on RubyGems! 🚀

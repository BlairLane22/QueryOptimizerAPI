# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-01-15

### Added
- Initial release of Query Optimizer Client gem
- Basic API client for Rails Database Query Optimizer API
- N+1 query detection integration
- Slow query analysis integration
- Missing index detection integration
- Rails middleware for automatic query monitoring
- CI/CD integration with threshold-based pass/fail
- Comprehensive configuration options
- Rake tasks for analysis and configuration checking
- Rails generator for easy installation
- Background job for asynchronous analysis
- Error handling with specific exception classes
- Rate limiting support with automatic retry
- Comprehensive logging and debugging support

### Features
- **Client**: HTTP client with retry logic and error handling
- **Configuration**: Flexible configuration via environment variables and initializers
- **Middleware**: Automatic query collection and analysis
- **Rake Tasks**: Command-line tools for analysis and CI integration
- **Generator**: Rails generator for easy setup
- **Jobs**: Background job for asynchronous processing
- **Logging**: Detailed logging with configurable levels

### Supported Ruby Versions
- Ruby 3.0+
- Rails 6.0+

### API Endpoints Supported
- `POST /analyze` - Query analysis with optimization suggestions
- `POST /analyze_ci` - CI/CD integration with pass/fail scoring
- `GET /health` - Health check
- `POST /api_keys` - API key generation

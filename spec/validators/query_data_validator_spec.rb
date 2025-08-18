require 'rails_helper'

RSpec.describe QueryDataValidator do
  describe '.validate_queries' do
    context 'with valid queries' do
      let(:valid_queries) do
        [
          { sql: "SELECT * FROM users WHERE id = 1", duration_ms: 100 },
          { sql: "SELECT name FROM posts WHERE user_id = 2", duration_ms: 50 }
        ]
      end

      it 'returns no errors for valid queries' do
        errors = QueryDataValidator.validate_queries(valid_queries)
        expect(errors).to be_empty
      end
    end

    context 'with invalid input types' do
      it 'returns error when queries is not an array' do
        errors = QueryDataValidator.validate_queries("not an array")
        expect(errors).to include("Queries must be an array")
      end

      it 'returns error when queries array is empty' do
        errors = QueryDataValidator.validate_queries([])
        expect(errors).to include("At least one query is required")
      end

      it 'returns error when too many queries provided' do
        large_queries = Array.new(101) { { sql: "SELECT 1", duration_ms: 10 } }
        errors = QueryDataValidator.validate_queries(large_queries)
        expect(errors).to include("Maximum 100 queries allowed per request")
      end
    end

    context 'with invalid SQL queries' do
      it 'returns error for missing SQL' do
        queries = [{ duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: SQL query is required")
      end

      it 'returns error for empty SQL' do
        queries = [{ sql: "", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: SQL query is required")
      end

      it 'returns error for SQL that is too short' do
        queries = [{ sql: "SELECT 1", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: SQL query must be between 10 and 10,000 characters")
      end

      it 'returns error for SQL that is too long' do
        long_sql = "SELECT * FROM users WHERE " + "id = 1 AND " * 1000 + "name = 'test'"
        queries = [{ sql: long_sql, duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: SQL query must be between 10 and 10,000 characters")
      end
    end

    context 'with invalid duration values' do
      it 'returns error for negative duration' do
        queries = [{ sql: "SELECT * FROM users", duration_ms: -10 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Duration must be between 0 and 3,600,000 milliseconds")
      end

      it 'returns error for excessive duration' do
        queries = [{ sql: "SELECT * FROM users", duration_ms: 4000000 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Duration must be between 0 and 3,600,000 milliseconds")
      end

      it 'allows nil duration' do
        queries = [{ sql: "SELECT * FROM users", duration_ms: nil }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to be_empty
      end
    end

    context 'with dangerous SQL patterns' do
      it 'detects DROP statements' do
        queries = [{ sql: "DROP TABLE users", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Contains potentially dangerous SQL pattern")
      end

      it 'detects DELETE without WHERE' do
        queries = [{ sql: "DELETE FROM users", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Contains potentially dangerous SQL pattern")
      end

      it 'allows DELETE with WHERE' do
        queries = [{ sql: "DELETE FROM users WHERE id = 1", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        dangerous_errors = errors.select { |e| e.include?("dangerous") }
        expect(dangerous_errors).to be_empty
      end

      it 'detects TRUNCATE statements' do
        queries = [{ sql: "TRUNCATE TABLE users", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Contains potentially dangerous SQL pattern")
      end

      it 'detects ALTER statements' do
        queries = [{ sql: "ALTER TABLE users ADD COLUMN email VARCHAR(255)", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Contains potentially dangerous SQL pattern")
      end

      it 'detects CREATE statements' do
        queries = [{ sql: "CREATE TABLE test (id INT)", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Contains potentially dangerous SQL pattern")
      end

      it 'detects UPDATE without WHERE' do
        queries = [{ sql: "UPDATE users SET name = 'test'", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Contains potentially dangerous SQL pattern")
      end

      it 'allows UPDATE with WHERE' do
        queries = [{ sql: "UPDATE users SET name = 'test' WHERE id = 1", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        dangerous_errors = errors.select { |e| e.include?("dangerous") }
        expect(dangerous_errors).to be_empty
      end
    end

    context 'with invalid SQL structure' do
      it 'detects non-SQL statements' do
        queries = [{ sql: "This is not SQL", duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Must be a valid SQL statement (SELECT, INSERT, UPDATE, or DELETE)")
      end

      it 'detects overly complex queries' do
        complex_sql = "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM users)))))"
        queries = [{ sql: complex_sql, duration_ms: 100 }]
        errors = QueryDataValidator.validate_queries(queries)
        expect(errors).to include("Query 1: Query appears to be too complex (too many subqueries)")
      end
    end

    context 'with multiple queries and mixed validity' do
      let(:mixed_queries) do
        [
          { sql: "SELECT * FROM users WHERE id = 1", duration_ms: 100 },  # Valid
          { sql: "", duration_ms: 50 },  # Invalid - empty SQL
          { sql: "DROP TABLE users", duration_ms: 200 },  # Invalid - dangerous
          { sql: "SELECT name FROM posts WHERE user_id = 2", duration_ms: -10 }  # Invalid - negative duration
        ]
      end

      it 'returns all validation errors with query numbers' do
        errors = QueryDataValidator.validate_queries(mixed_queries)

        expect(errors).to include("Query 2: SQL query is required")
        expect(errors).to include("Query 3: Contains potentially dangerous SQL pattern")
        expect(errors).to include("Query 4: Duration must be between 0 and 3,600,000 milliseconds")
        expect(errors.length).to be >= 3  # May have additional validation errors
      end
    end

    context 'with string keys instead of symbol keys' do
      let(:string_key_queries) do
        [
          { 'sql' => "SELECT * FROM users WHERE id = 1", 'duration_ms' => 100 }
        ]
      end

      it 'handles string keys correctly' do
        errors = QueryDataValidator.validate_queries(string_key_queries)
        expect(errors).to be_empty
      end
    end
  end

  describe 'individual validator' do
    context 'with valid data' do
      let(:validator) { QueryDataValidator.new(sql: "SELECT * FROM users", duration_ms: 100) }

      it 'is valid' do
        expect(validator).to be_valid
      end
    end

    context 'with invalid data' do
      let(:validator) { QueryDataValidator.new(sql: "", duration_ms: -10) }

      it 'is invalid' do
        expect(validator).not_to be_valid
        expect(validator.errors[:sql]).to include("SQL query is required")
        expect(validator.errors[:duration_ms]).to include("Duration must be between 0 and 3,600,000 milliseconds")
      end
    end
  end
end

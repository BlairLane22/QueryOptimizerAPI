require 'rails_helper'

RSpec.describe SqlParserService do
  describe '#initialize' do
    it 'parses a valid SQL query' do
      sql = "SELECT * FROM users WHERE id = 1"
      parser = SqlParserService.new(sql)
      
      expect(parser.valid?).to be true
      expect(parser.errors).to be_empty
    end

    it 'handles invalid SQL gracefully' do
      sql = "INVALID SQL QUERY"
      parser = SqlParserService.new(sql)
      
      expect(parser.valid?).to be false
      expect(parser.errors).not_to be_empty
    end
  end

  describe '#query_type' do
    it 'identifies SELECT queries' do
      sql = "SELECT * FROM users"
      parser = SqlParserService.new(sql)
      
      expect(parser.query_type).to eq('SELECT')
    end

    it 'identifies INSERT queries' do
      sql = "INSERT INTO users (name) VALUES ('John')"
      parser = SqlParserService.new(sql)
      
      expect(parser.query_type).to eq('INSERT')
    end

    it 'identifies UPDATE queries' do
      sql = "UPDATE users SET name = 'Jane' WHERE id = 1"
      parser = SqlParserService.new(sql)
      
      expect(parser.query_type).to eq('UPDATE')
    end

    it 'identifies DELETE queries' do
      sql = "DELETE FROM users WHERE id = 1"
      parser = SqlParserService.new(sql)
      
      expect(parser.query_type).to eq('DELETE')
    end
  end

  describe '#primary_table' do
    it 'extracts table from SELECT query' do
      sql = "SELECT * FROM users WHERE id = 1"
      parser = SqlParserService.new(sql)
      
      expect(parser.primary_table).to eq('users')
    end

    it 'extracts table from INSERT query' do
      sql = "INSERT INTO posts (title) VALUES ('Test')"
      parser = SqlParserService.new(sql)
      
      expect(parser.primary_table).to eq('posts')
    end

    it 'extracts table from UPDATE query' do
      sql = "UPDATE comments SET content = 'Updated' WHERE id = 1"
      parser = SqlParserService.new(sql)
      
      expect(parser.primary_table).to eq('comments')
    end

    it 'extracts table from DELETE query' do
      sql = "DELETE FROM sessions WHERE id = 1"
      parser = SqlParserService.new(sql)
      
      expect(parser.primary_table).to eq('sessions')
    end
  end

  describe '#where_conditions' do
    it 'extracts simple WHERE conditions' do
      sql = "SELECT * FROM users WHERE id = 1"
      parser = SqlParserService.new(sql)
      
      conditions = parser.where_conditions
      expect(conditions).not_to be_empty
      
      condition = conditions.first
      expect(condition[:column]).to eq('id')
      expect(condition[:operator]).to eq('=')
      expect(condition[:value]).to eq(1)
      expect(condition[:value_type]).to eq('integer')
    end

    it 'extracts parameterized WHERE conditions' do
      sql = "SELECT * FROM users WHERE email = $1"
      parser = SqlParserService.new(sql)
      
      conditions = parser.where_conditions
      expect(conditions).not_to be_empty
      
      condition = conditions.first
      expect(condition[:column]).to eq('email')
      expect(condition[:operator]).to eq('=')
      expect(condition[:value_type]).to eq('param')
    end
  end

  describe '#potential_n_plus_one?' do
    it 'identifies potential N+1 queries with ID lookups' do
      sql = "SELECT * FROM posts WHERE user_id = $1"
      parser = SqlParserService.new(sql)
      
      expect(parser.potential_n_plus_one?).to be true
    end

    it 'identifies potential N+1 queries with table.id lookups' do
      sql = "SELECT * FROM posts WHERE posts.id = $1"
      parser = SqlParserService.new(sql)
      
      expect(parser.potential_n_plus_one?).to be true
    end

    it 'does not flag non-ID WHERE clauses' do
      sql = "SELECT * FROM users WHERE email = $1"
      parser = SqlParserService.new(sql)
      
      expect(parser.potential_n_plus_one?).to be false
    end

    it 'does not flag non-SELECT queries' do
      sql = "INSERT INTO posts (user_id) VALUES (1)"
      parser = SqlParserService.new(sql)
      
      expect(parser.potential_n_plus_one?).to be false
    end
  end

  describe '#query_signature' do
    it 'generates consistent signatures for similar queries' do
      sql1 = "SELECT * FROM users WHERE id = 1"
      sql2 = "SELECT * FROM users WHERE id = 2"
      sql3 = "SELECT * FROM users WHERE id = $1"
      
      parser1 = SqlParserService.new(sql1)
      parser2 = SqlParserService.new(sql2)
      parser3 = SqlParserService.new(sql3)
      
      expect(parser1.query_signature).to eq(parser2.query_signature)
      expect(parser1.query_signature).to eq(parser3.query_signature)
    end

    it 'generates different signatures for different queries' do
      sql1 = "SELECT * FROM users WHERE id = 1"
      sql2 = "SELECT * FROM posts WHERE id = 1"
      
      parser1 = SqlParserService.new(sql1)
      parser2 = SqlParserService.new(sql2)
      
      expect(parser1.query_signature).not_to eq(parser2.query_signature)
    end
  end

  describe '#where_columns' do
    it 'extracts column names from WHERE clauses' do
      sql = "SELECT * FROM users WHERE email = 'test@example.com' AND active = true"
      parser = SqlParserService.new(sql)
      
      columns = parser.where_columns
      expect(columns).to include('email')
      expect(columns).to include('active')
    end
  end

  describe '#all_tables' do
    it 'extracts table names from simple queries' do
      sql = "SELECT * FROM users"
      parser = SqlParserService.new(sql)
      
      tables = parser.all_tables
      expect(tables).to include('users')
    end
  end

  describe '#order_by_columns' do
    it 'extracts ORDER BY columns' do
      sql = "SELECT * FROM posts ORDER BY created_at DESC"
      parser = SqlParserService.new(sql)

      columns = parser.order_by_columns
      expect(columns).to include('created_at')
    end

    it 'extracts multiple ORDER BY columns' do
      sql = "SELECT * FROM posts ORDER BY created_at DESC, title ASC"
      parser = SqlParserService.new(sql)

      columns = parser.order_by_columns
      expect(columns).to include('created_at')
      expect(columns).to include('title')
    end

    it 'handles table-prefixed columns in ORDER BY' do
      sql = "SELECT * FROM posts ORDER BY posts.created_at"
      parser = SqlParserService.new(sql)

      columns = parser.order_by_columns
      expect(columns).to include('created_at')
    end
  end

  describe '.parse' do
    it 'provides a class method for parsing' do
      sql = "SELECT * FROM users"
      parser = SqlParserService.parse(sql)

      expect(parser).to be_a(SqlParserService)
      expect(parser.primary_table).to eq('users')
    end
  end
end

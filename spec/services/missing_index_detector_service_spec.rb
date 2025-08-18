require 'rails_helper'

RSpec.describe MissingIndexDetectorService do
  let(:app_profile) { create(:app_profile) }

  describe '#detect' do
    context 'with frequent WHERE clause usage' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'test@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT id FROM users WHERE email = 'another@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT name FROM users WHERE email = 'third@example.com'",
            table_name: "users"
          )
        ]
      end

      it 'suggests single column index for frequently used WHERE columns' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 3)
        suggestions = detector.detect

        expect(suggestions).not_to be_empty
        
        email_suggestion = suggestions.find { |s| s[:columns] == ['email'] }
        expect(email_suggestion).not_to be_nil
        expect(email_suggestion[:type]).to eq('single_column_index')
        expect(email_suggestion[:table_name]).to eq('users')
        expect(email_suggestion[:frequency]).to eq(3)
        expect(email_suggestion[:sql]).to include('CREATE INDEX idx_users_email')
      end

      it 'provides detailed suggestion information' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 3)
        suggestions = detector.detect

        suggestion = suggestions.first
        expect(suggestion[:reason]).to include('WHERE clauses')
        expect(suggestion[:impact]).to eq('high')
        expect(suggestion[:description]).to include('email')
        expect(suggestion[:priority]).to be > 0
      end
    end

    context 'with foreign key patterns' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 1",
            table_name: "posts"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT title FROM posts WHERE user_id = 2",
            table_name: "posts"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT content FROM posts WHERE user_id = 3",
            table_name: "posts"
          )
        ]
      end

      it 'suggests foreign key indexes with high priority' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 3)
        suggestions = detector.detect

        fk_suggestion = suggestions.find { |s| s[:type] == 'foreign_key_index' }
        expect(fk_suggestion).not_to be_nil
        expect(fk_suggestion[:columns]).to eq(['user_id'])
        expect(fk_suggestion[:priority]).to be >= 4 # Foreign keys get bonus priority
        expect(fk_suggestion[:reason]).to include('Foreign key')
      end
    end

    context 'with composite index opportunities' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE status = 'active' AND role = 'admin'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT id FROM users WHERE status = 'inactive' AND role = 'user'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT name FROM users WHERE role = 'moderator' AND status = 'active'",
            table_name: "users"
          )
        ]
      end

      it 'suggests composite indexes for frequently combined columns' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 3)
        suggestions = detector.detect

        composite_suggestion = suggestions.find { |s| s[:type] == 'composite_index' }
        expect(composite_suggestion).not_to be_nil
        expect(composite_suggestion[:columns].sort).to eq(['role', 'status'])
        expect(composite_suggestion[:sql]).to include('role, status')
        expect(composite_suggestion[:reason]).to include('together')
      end
    end

    context 'with ORDER BY patterns' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts ORDER BY created_at DESC",
            table_name: "posts"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT title FROM posts ORDER BY created_at ASC",
            table_name: "posts"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT id FROM posts ORDER BY created_at",
            table_name: "posts"
          )
        ]
      end

      it 'suggests indexes for frequently used ORDER BY columns' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 3)
        suggestions = detector.detect

        order_suggestion = suggestions.find { |s| s[:type] == 'order_by_index' }
        expect(order_suggestion).not_to be_nil
        expect(order_suggestion[:columns]).to eq(['created_at'])
        expect(order_suggestion[:reason]).to include('ORDER BY')
        expect(order_suggestion[:impact]).to eq('medium')
      end
    end

    context 'with mixed table queries' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'test@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 1",
            table_name: "posts"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'another@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 2",
            table_name: "posts"
          )
        ]
      end

      it 'groups suggestions by table correctly' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 2)
        suggestions = detector.detect

        table_names = suggestions.map { |s| s[:table_name] }.uniq
        expect(table_names).to include('users')
        expect(table_names).to include('posts')
        
        users_suggestions = suggestions.select { |s| s[:table_name] == 'users' }
        posts_suggestions = suggestions.select { |s| s[:table_name] == 'posts' }
        
        expect(users_suggestions).not_to be_empty
        expect(posts_suggestions).not_to be_empty
      end
    end

    context 'with low frequency patterns' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'test@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE name = 'John'",
            table_name: "users"
          )
        ]
      end

      it 'does not suggest indexes for infrequent patterns' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 3)
        suggestions = detector.detect

        expect(suggestions).to be_empty
      end
    end

    context 'with table prefix in column names' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE users.email = 'test@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE users.email = 'another@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE users.email = 'third@example.com'",
            table_name: "users"
          )
        ]
      end

      it 'handles table-prefixed column names correctly' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 3)
        suggestions = detector.detect

        suggestion = suggestions.find { |s| s[:columns] == ['email'] }
        expect(suggestion).not_to be_nil
        expect(suggestion[:sql]).to include('idx_users_email')
      end
    end

    context 'with duplicate suggestions' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'test@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'another@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'third@example.com'",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users ORDER BY email",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users ORDER BY email DESC",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users ORDER BY email ASC",
            table_name: "users"
          )
        ]
      end

      it 'deduplicates suggestions and keeps highest priority' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 3)
        suggestions = detector.detect

        email_suggestions = suggestions.select { |s| s[:columns] == ['email'] }
        expect(email_suggestions.length).to eq(1) # Should be deduplicated
        
        # Should keep the higher priority one (WHERE clause has higher priority than ORDER BY)
        expect(email_suggestions.first[:type]).to eq('single_column_index')
      end
    end

    context 'with priority calculation' do
      let(:queries) do
        # Create many queries to test different priority levels
        Array.new(15) do |i|
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'test#{i}@example.com'",
            table_name: "users"
          )
        end
      end

      it 'calculates priority based on frequency' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 10)
        suggestions = detector.detect

        suggestion = suggestions.first
        expect(suggestion[:frequency]).to eq(15)
        expect(suggestion[:priority]).to eq(5) # High frequency should get max priority
      end
    end

    context 'with invalid queries' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "INVALID SQL QUERY",
            table_name: "users"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE email = 'test@example.com'",
            table_name: "users"
          )
        ]
      end

      it 'handles invalid queries gracefully' do
        detector = MissingIndexDetectorService.new(queries, frequency_threshold: 1)
        suggestions = detector.detect

        # Should still process valid queries
        expect(suggestions).not_to be_empty
        expect(suggestions.first[:columns]).to eq(['email'])
      end
    end
  end

  describe '.detect' do
    it 'provides a class method for detection' do
      queries = [
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT * FROM users WHERE email = 'test@example.com'",
          table_name: "users"
        )
      ]

      suggestions = MissingIndexDetectorService.detect(queries, frequency_threshold: 1)
      expect(suggestions).not_to be_empty
    end
  end

  describe '#calculate_priority' do
    let(:detector) { MissingIndexDetectorService.new([]) }

    it 'calculates priority levels correctly' do
      expect(detector.send(:calculate_priority, 2)).to eq(1)
      expect(detector.send(:calculate_priority, 4)).to eq(2)
      expect(detector.send(:calculate_priority, 8)).to eq(3)
      expect(detector.send(:calculate_priority, 12)).to eq(4)
      expect(detector.send(:calculate_priority, 15)).to eq(5)
    end

    it 'applies bonus correctly' do
      expect(detector.send(:calculate_priority, 2, bonus: 2)).to eq(3)
      expect(detector.send(:calculate_priority, 25, bonus: 2)).to eq(5) # Capped at 5
    end
  end

  describe 'custom frequency threshold' do
    let(:queries) do
      [
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT * FROM users WHERE email = 'test@example.com'",
          table_name: "users"
        ),
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT * FROM users WHERE email = 'another@example.com'",
          table_name: "users"
        )
      ]
    end

    it 'respects custom frequency threshold' do
      detector = MissingIndexDetectorService.new(queries, frequency_threshold: 2)
      suggestions = detector.detect

      expect(suggestions).not_to be_empty
    end

    it 'filters out patterns below threshold' do
      detector = MissingIndexDetectorService.new(queries, frequency_threshold: 5)
      suggestions = detector.detect

      expect(suggestions).to be_empty
    end
  end
end

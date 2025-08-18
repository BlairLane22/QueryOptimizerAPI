require 'rails_helper'

RSpec.describe SlowQueryAnalyzerService do
  let(:app_profile) { create(:app_profile) }

  describe '#analyze' do
    context 'with fast queries' do
      let(:fast_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT id, name FROM users WHERE id = 1",
          duration_ms: 50,
          table_name: "users",
          query_type: "SELECT"
        )
      end

      it 'does not flag fast queries' do
        analyzer = SlowQueryAnalyzerService.new([fast_query])
        issues = analyzer.analyze

        expect(issues).to be_empty
      end
    end

    context 'with slow queries' do
      let(:slow_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT * FROM users WHERE email LIKE '%@example.com'",
          duration_ms: 500,
          table_name: "users",
          query_type: "SELECT"
        )
      end

      it 'identifies slow queries' do
        analyzer = SlowQueryAnalyzerService.new([slow_query])
        issues = analyzer.analyze

        expect(issues).not_to be_empty
        
        issue = issues.first
        expect(issue[:type]).to eq('slow_query')
        expect(issue[:severity]).to eq('slow')
        expect(issue[:duration_ms]).to eq(500)
        expect(issue[:table_name]).to eq('users')
      end

      it 'provides optimization suggestions' do
        analyzer = SlowQueryAnalyzerService.new([slow_query])
        issues = analyzer.analyze

        issue = issues.first
        suggestions = issue[:suggestions]
        
        expect(suggestions).not_to be_empty
        expect(suggestions.any? { |s| s[:title].include?('Slow Query') }).to be true
        expect(suggestions.any? { |s| s[:title].include?('SELECT *') }).to be true
      end
    end

    context 'with very slow queries' do
      let(:very_slow_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT * FROM posts",
          duration_ms: 2000,
          table_name: "posts",
          query_type: "SELECT"
        )
      end

      it 'identifies very slow queries with correct severity' do
        analyzer = SlowQueryAnalyzerService.new([very_slow_query])
        issues = analyzer.analyze

        issue = issues.first
        expect(issue[:severity]).to eq('very_slow')
        expect(issue[:duration_ms]).to eq(2000)
      end

      it 'provides high priority suggestions' do
        analyzer = SlowQueryAnalyzerService.new([very_slow_query])
        issues = analyzer.analyze

        issue = issues.first
        suggestions = issue[:suggestions]
        
        high_priority_suggestion = suggestions.find { |s| s[:priority] == 'high' }
        expect(high_priority_suggestion).not_to be_nil
        expect(high_priority_suggestion[:title]).to include('Very Slow Query')
      end
    end

    context 'with critical queries' do
      let(:critical_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT * FROM users WHERE UPPER(email) = 'TEST@EXAMPLE.COM'",
          duration_ms: 8000,
          table_name: "users",
          query_type: "SELECT"
        )
      end

      it 'identifies critical queries' do
        analyzer = SlowQueryAnalyzerService.new([critical_query])
        issues = analyzer.analyze

        issue = issues.first
        expect(issue[:severity]).to eq('critical')
        expect(issue[:duration_ms]).to eq(8000)
      end

      it 'provides critical priority suggestions' do
        analyzer = SlowQueryAnalyzerService.new([critical_query])
        issues = analyzer.analyze

        issue = issues.first
        suggestions = issue[:suggestions]
        
        critical_suggestion = suggestions.find { |s| s[:priority] == 'critical' }
        expect(critical_suggestion).not_to be_nil
        expect(critical_suggestion[:title]).to include('Critical Performance Issue')
      end
    end

    context 'with complex queries' do
      let(:complex_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT * FROM users WHERE UPPER(name) LIKE '%JOHN%' OR email LIKE '%@gmail.com'",
          duration_ms: 1500,
          table_name: "users",
          query_type: "SELECT"
        )
      end

      it 'identifies complexity issues' do
        analyzer = SlowQueryAnalyzerService.new([complex_query])
        issues = analyzer.analyze

        issue = issues.first
        complexity_issues = issue[:complexity_issues]
        
        expect(complexity_issues).not_to be_empty
        
        issue_types = complexity_issues.map { |ci| ci[:type] }
        expect(issue_types).to include('select_star')
        expect(issue_types).to include('function_in_where')
        expect(issue_types).to include('or_conditions')
      end

      it 'provides specific optimization suggestions for complexity issues' do
        analyzer = SlowQueryAnalyzerService.new([complex_query])
        issues = analyzer.analyze

        issue = issues.first
        suggestions = issue[:suggestions]
        
        suggestion_titles = suggestions.map { |s| s[:title] }
        expect(suggestion_titles).to include('Avoid SELECT *')
        expect(suggestion_titles).to include('Avoid functions in WHERE clause')
        expect(suggestion_titles).to include('Consider alternatives to OR')
      end
    end

    context 'with queries without WHERE clause' do
      let(:no_where_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT id, name FROM users",
          duration_ms: 800,
          table_name: "users",
          query_type: "SELECT"
        )
      end

      it 'identifies missing WHERE clause as high impact' do
        analyzer = SlowQueryAnalyzerService.new([no_where_query])
        issues = analyzer.analyze

        issue = issues.first
        complexity_issues = issue[:complexity_issues]
        
        no_where_issue = complexity_issues.find { |ci| ci[:type] == 'no_where_clause' }
        expect(no_where_issue).not_to be_nil
        expect(no_where_issue[:impact]).to eq('high')
      end
    end

    context 'with LIKE queries using leading wildcards' do
      let(:wildcard_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT id FROM users WHERE name LIKE '%john%'",
          duration_ms: 600,
          table_name: "users",
          query_type: "SELECT"
        )
      end

      it 'identifies leading wildcard LIKE as high impact' do
        analyzer = SlowQueryAnalyzerService.new([wildcard_query])
        issues = analyzer.analyze

        issue = issues.first
        complexity_issues = issue[:complexity_issues]
        
        wildcard_issue = complexity_issues.find { |ci| ci[:type] == 'leading_wildcard_like' }
        expect(wildcard_issue).not_to be_nil
        expect(wildcard_issue[:impact]).to eq('high')
      end

      it 'provides LIKE optimization suggestions' do
        analyzer = SlowQueryAnalyzerService.new([wildcard_query])
        issues = analyzer.analyze

        issue = issues.first
        suggestions = issue[:suggestions]
        
        like_suggestion = suggestions.find { |s| s[:title].include?('LIKE patterns') }
        expect(like_suggestion).not_to be_nil
        expect(like_suggestion[:recommendation]).to include('full-text search')
      end
    end

    context 'with subqueries' do
      let(:subquery_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT * FROM users WHERE id IN (SELECT user_id FROM posts WHERE created_at > '2023-01-01')",
          duration_ms: 750,
          table_name: "users",
          query_type: "SELECT"
        )
      end

      it 'identifies subqueries' do
        analyzer = SlowQueryAnalyzerService.new([subquery_query])
        issues = analyzer.analyze

        issue = issues.first
        complexity_issues = issue[:complexity_issues]
        
        subquery_issue = complexity_issues.find { |ci| ci[:type] == 'subquery' }
        expect(subquery_issue).not_to be_nil
        expect(subquery_issue[:impact]).to eq('medium')
      end

      it 'suggests JOIN alternatives' do
        analyzer = SlowQueryAnalyzerService.new([subquery_query])
        issues = analyzer.analyze

        issue = issues.first
        suggestions = issue[:suggestions]
        
        join_suggestion = suggestions.find { |s| s[:title].include?('JOIN instead of subquery') }
        expect(join_suggestion).not_to be_nil
        expect(join_suggestion[:recommendation]).to include('JOINs')
      end
    end

    context 'with index suggestions' do
      let(:indexable_query) do
        create(:query_analysis,
          app_profile: app_profile,
          sql_query: "SELECT id, name FROM users WHERE email = 'test@example.com' AND status = 'active'",
          duration_ms: 400,
          table_name: "users",
          query_type: "SELECT"
        )
      end

      it 'suggests indexes for WHERE columns' do
        analyzer = SlowQueryAnalyzerService.new([indexable_query])
        issues = analyzer.analyze

        issue = issues.first
        suggestions = issue[:suggestions]
        
        index_suggestion = suggestions.find { |s| s[:title].include?('adding indexes') }
        expect(index_suggestion).not_to be_nil
        expect(index_suggestion[:description]).to include('email')
        expect(index_suggestion[:description]).to include('status')
        expect(index_suggestion[:sql_example]).to include('CREATE INDEX')
      end
    end

    context 'with multiple queries' do
      let(:queries) do
        [
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM users",
            duration_ms: 50,  # Fast - should be ignored
            table_name: "users",
            query_type: "SELECT"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE title LIKE '%test%'",
            duration_ms: 800,  # Slow
            table_name: "posts",
            query_type: "SELECT"
          ),
          create(:query_analysis,
            app_profile: app_profile,
            sql_query: "SELECT * FROM comments",
            duration_ms: 3000,  # Very slow
            table_name: "comments",
            query_type: "SELECT"
          )
        ]
      end

      it 'analyzes multiple queries correctly' do
        analyzer = SlowQueryAnalyzerService.new(queries)
        issues = analyzer.analyze

        expect(issues.length).to eq(2)  # Only slow queries
        
        severities = issues.map { |i| i[:severity] }
        expect(severities).to include('slow')
        expect(severities).to include('very_slow')
      end
    end
  end

  describe '.analyze' do
    it 'provides a class method for analysis' do
      query = create(:query_analysis,
        app_profile: app_profile,
        sql_query: "SELECT * FROM users",
        duration_ms: 500,
        table_name: "users",
        query_type: "SELECT"
      )

      issues = SlowQueryAnalyzerService.analyze([query])
      expect(issues).not_to be_empty
    end
  end

  describe '#calculate_severity' do
    let(:analyzer) { SlowQueryAnalyzerService.new([]) }

    it 'calculates severity levels correctly' do
      expect(analyzer.send(:calculate_severity, 100)).to eq('normal')
      expect(analyzer.send(:calculate_severity, 300)).to eq('slow')
      expect(analyzer.send(:calculate_severity, 1500)).to eq('very_slow')
      expect(analyzer.send(:calculate_severity, 8000)).to eq('critical')
    end
  end

  describe 'custom thresholds' do
    let(:query) do
      create(:query_analysis,
        app_profile: app_profile,
        sql_query: "SELECT * FROM users",
        duration_ms: 150,
        table_name: "users",
        query_type: "SELECT"
      )
    end

    it 'respects custom slow threshold' do
      analyzer = SlowQueryAnalyzerService.new([query], slow_threshold: 100)
      issues = analyzer.analyze

      expect(issues).not_to be_empty
      expect(issues.first[:severity]).to eq('slow')
    end

    it 'ignores queries below custom threshold' do
      analyzer = SlowQueryAnalyzerService.new([query], slow_threshold: 200)
      issues = analyzer.analyze

      expect(issues).to be_empty
    end
  end
end

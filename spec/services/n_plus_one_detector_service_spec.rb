require 'rails_helper'

RSpec.describe NPlusOneDetectorService do
  let(:app_profile) { create(:app_profile) }
  let(:base_time) { Time.current }

  describe '#detect' do
    context 'when there are N+1 queries' do
      let(:queries) do
        [
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 1",
            analyzed_at: base_time
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 2",
            analyzed_at: base_time + 1.second
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 3",
            analyzed_at: base_time + 2.seconds
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 4",
            analyzed_at: base_time + 3.seconds
          )
        ]
      end

      it 'detects N+1 pattern' do
        detector = NPlusOneDetectorService.new(queries, threshold: 3)
        patterns = detector.detect

        expect(patterns).not_to be_empty
        
        pattern = patterns.first
        expect(pattern[:type]).to eq('n_plus_one')
        expect(pattern[:table_name]).to eq('posts')
        expect(pattern[:column_name]).to eq('user_id')
        expect(pattern[:query_count]).to eq(4)
      end

      it 'provides helpful suggestions' do
        detector = NPlusOneDetectorService.new(queries, threshold: 3)
        patterns = detector.detect

        pattern = patterns.first
        suggestion = pattern[:suggestion]
        
        expect(suggestion[:title]).to include('includes()')
        expect(suggestion[:rails_suggestion]).to include('includes(:users)')
        expect(suggestion[:example_code]).to include('includes(:users)')
      end

      it 'calculates severity correctly' do
        detector = NPlusOneDetectorService.new(queries, threshold: 3)
        patterns = detector.detect

        pattern = patterns.first
        expect(pattern[:severity]).to eq('low') # 4 queries = low severity
      end
    end

    context 'when queries are spread over time' do
      let(:queries) do
        [
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 1",
            analyzed_at: base_time
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 2",
            analyzed_at: base_time + 10.minutes  # Too far apart
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 3",
            analyzed_at: base_time + 20.minutes
          )
        ]
      end

      it 'does not detect N+1 pattern' do
        detector = NPlusOneDetectorService.new(queries, threshold: 3, time_window: 5.seconds)
        patterns = detector.detect

        expect(patterns).to be_empty
      end
    end

    context 'when there are too few queries' do
      let(:queries) do
        [
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 1",
            analyzed_at: base_time
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 2",
            analyzed_at: base_time + 1.second
          )
        ]
      end

      it 'does not detect N+1 pattern' do
        detector = NPlusOneDetectorService.new(queries, threshold: 3)
        patterns = detector.detect

        expect(patterns).to be_empty
      end
    end

    context 'with different query structures' do
      let(:queries) do
        [
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 1",
            analyzed_at: base_time
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM comments WHERE post_id = 1",  # Different table
            analyzed_at: base_time + 1.second
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM posts WHERE user_id = 2",
            analyzed_at: base_time + 2.seconds
          )
        ]
      end

      it 'does not detect N+1 pattern' do
        detector = NPlusOneDetectorService.new(queries, threshold: 3)
        patterns = detector.detect

        expect(patterns).to be_empty
      end
    end

    context 'with ID lookups' do
      let(:queries) do
        [
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE id = 1",
            analyzed_at: base_time
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE id = 2",
            analyzed_at: base_time + 1.second
          ),
          create(:query_analysis, 
            app_profile: app_profile,
            sql_query: "SELECT * FROM users WHERE id = 3",
            analyzed_at: base_time + 2.seconds
          )
        ]
      end

      it 'detects ID lookup pattern' do
        detector = NPlusOneDetectorService.new(queries, threshold: 3)
        patterns = detector.detect

        expect(patterns).not_to be_empty
        
        pattern = patterns.first
        expect(pattern[:type]).to eq('n_plus_one')
        expect(pattern[:table_name]).to eq('users')
        expect(pattern[:column_name]).to eq('id')
      end

      it 'provides ID lookup suggestions' do
        detector = NPlusOneDetectorService.new(queries, threshold: 3)
        patterns = detector.detect

        pattern = patterns.first
        suggestion = pattern[:suggestion]
        
        expect(suggestion[:title]).to include('ID lookups')
        expect(suggestion[:rails_suggestion]).to include('where(id:')
        expect(suggestion[:sql_suggestion]).to include('WHERE id IN')
      end
    end
  end

  describe '.detect' do
    it 'provides a class method for detection' do
      queries = [
        create(:query_analysis, 
          app_profile: app_profile,
          sql_query: "SELECT * FROM posts WHERE user_id = 1",
          analyzed_at: base_time
        ),
        create(:query_analysis, 
          app_profile: app_profile,
          sql_query: "SELECT * FROM posts WHERE user_id = 2",
          analyzed_at: base_time + 1.second
        ),
        create(:query_analysis, 
          app_profile: app_profile,
          sql_query: "SELECT * FROM posts WHERE user_id = 3",
          analyzed_at: base_time + 2.seconds
        )
      ]

      patterns = NPlusOneDetectorService.detect(queries, threshold: 3)
      expect(patterns).not_to be_empty
    end
  end

  describe '#calculate_severity' do
    let(:detector) { NPlusOneDetectorService.new([]) }

    it 'calculates severity levels correctly' do
      expect(detector.send(:calculate_severity, 3)).to eq('low')
      expect(detector.send(:calculate_severity, 10)).to eq('medium')
      expect(detector.send(:calculate_severity, 25)).to eq('high')
      expect(detector.send(:calculate_severity, 100)).to eq('critical')
    end
  end
end

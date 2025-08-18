require 'rails_helper'

RSpec.describe QueryAnalysis, type: :model do
  describe 'validations' do
    let(:app_profile) { create(:app_profile) }

    it 'validates presence of sql_query' do
      query_analysis = QueryAnalysis.new(app_profile: app_profile)
      expect(query_analysis).not_to be_valid
      expect(query_analysis.errors[:sql_query]).to include("can't be blank")
    end

    it 'validates presence of app_profile' do
      query_analysis = QueryAnalysis.new(sql_query: 'SELECT * FROM users')
      expect(query_analysis).not_to be_valid
      expect(query_analysis.errors[:app_profile]).to include("must exist")
    end

    it 'validates presence of analyzed_at' do
      query_analysis = QueryAnalysis.new(
        sql_query: 'SELECT * FROM users',
        app_profile: app_profile
      )
      expect(query_analysis).not_to be_valid
      expect(query_analysis.errors[:analyzed_at]).to include("can't be blank")
    end

    it 'validates query_type inclusion' do
      query_analysis = QueryAnalysis.new(
        sql_query: 'SELECT * FROM users',
        app_profile: app_profile,
        analyzed_at: Time.current,
        query_type: 'INVALID'
      )
      expect(query_analysis).not_to be_valid
      expect(query_analysis.errors[:query_type]).to include('is not included in the list')
    end
  end

  describe 'associations' do
    let(:query_analysis) { create(:query_analysis) }

    it 'belongs to app_profile' do
      expect(query_analysis).to respond_to(:app_profile)
      expect(query_analysis.app_profile).to be_an(AppProfile)
    end

    it 'has many optimization_suggestions' do
      expect(query_analysis).to respond_to(:optimization_suggestions)
      expect(query_analysis.optimization_suggestions).to be_empty
    end

    it 'destroys associated optimization_suggestions when deleted' do
      suggestion = create(:optimization_suggestion, query_analysis: query_analysis)

      expect {
        query_analysis.destroy
      }.to change(OptimizationSuggestion, :count).by(-1)
    end
  end

  describe 'scopes and methods' do
    let(:app_profile) { create(:app_profile) }

    before do
      create(:query_analysis,
        app_profile: app_profile,
        sql_query: 'SELECT * FROM users WHERE id = 1',
        duration_ms: 50
      )
      create(:query_analysis,
        app_profile: app_profile,
        sql_query: 'SELECT * FROM posts WHERE user_id = 1',
        duration_ms: 2000
      )
    end

    it 'can find slow queries' do
      slow_queries = QueryAnalysis.where('duration_ms > ?', 1000)
      expect(slow_queries.count).to eq(1)
      expect(slow_queries.first.duration_ms).to eq(2000)
    end

    it 'can group by table_name' do
      grouped = QueryAnalysis.group(:table_name).count
      expect(grouped).to be_a(Hash)
    end
  end

  describe 'JSON serialization' do
    let(:query_analysis) { create(:query_analysis, parsed_data: { tables: ['users'], columns: ['id', 'name'] }) }

    it 'serializes parsed_data as JSON' do
      expect(query_analysis.parsed_data).to be_a(Hash)
      expect(query_analysis.parsed_data['tables']).to eq(['users'])
      expect(query_analysis.parsed_data['columns']).to eq(['id', 'name'])
    end
  end

  describe 'factory' do
    it 'creates a valid query_analysis' do
      query_analysis = create(:query_analysis)

      expect(query_analysis).to be_valid
      expect(query_analysis.sql_query).to be_present
      expect(query_analysis.app_profile).to be_present
      expect(query_analysis.analyzed_at).to be_present
    end

    it 'creates query_analysis with custom attributes' do
      query_analysis = create(:query_analysis,
        sql_query: 'SELECT name FROM users',
        duration_ms: 100,
        table_name: 'users'
      )

      expect(query_analysis.sql_query).to eq('SELECT name FROM users')
      expect(query_analysis.duration_ms).to eq(100)
      expect(query_analysis.table_name).to eq('users')
    end
  end
end

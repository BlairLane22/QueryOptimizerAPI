require 'rails_helper'

RSpec.describe OptimizationSuggestion, type: :model do
  describe 'validations' do
    let(:query_analysis) { create(:query_analysis) }

    it 'validates presence of suggestion_type' do
      suggestion = OptimizationSuggestion.new(query_analysis: query_analysis)
      expect(suggestion).not_to be_valid
      expect(suggestion.errors[:suggestion_type]).to include("can't be blank")
    end

    it 'validates presence of title' do
      suggestion = OptimizationSuggestion.new(
        query_analysis: query_analysis,
        suggestion_type: 'n_plus_one'
      )
      expect(suggestion).not_to be_valid
      expect(suggestion.errors[:title]).to include("can't be blank")
    end

    it 'validates presence of description' do
      suggestion = OptimizationSuggestion.new(
        query_analysis: query_analysis,
        suggestion_type: 'n_plus_one',
        title: 'Test suggestion'
      )
      expect(suggestion).not_to be_valid
      expect(suggestion.errors[:description]).to include("can't be blank")
    end

    it 'validates presence of query_analysis' do
      suggestion = OptimizationSuggestion.new(
        suggestion_type: 'index',
        description: 'Add index on user_id'
      )
      expect(suggestion).not_to be_valid
      expect(suggestion.errors[:query_analysis]).to include("must exist")
    end

    it 'validates inclusion of suggestion_type' do
      suggestion = OptimizationSuggestion.new(
        query_analysis: query_analysis,
        suggestion_type: 'invalid_type',
        title: 'Test',
        description: 'Add index',
        priority: 2
      )
      expect(suggestion).not_to be_valid
      expect(suggestion.errors[:suggestion_type]).to include('is not included in the list')
    end

    it 'validates inclusion of priority' do
      suggestion = OptimizationSuggestion.new(
        query_analysis: query_analysis,
        suggestion_type: 'n_plus_one',
        title: 'Test',
        description: 'Add index',
        priority: 5
      )
      expect(suggestion).not_to be_valid
      expect(suggestion.errors[:priority]).to include('is not included in the list')
    end

    it 'allows valid priority values' do
      [1, 2, 3, 4].each do |priority|
        suggestion = OptimizationSuggestion.new(
          query_analysis: query_analysis,
          suggestion_type: 'n_plus_one',
          title: 'Test suggestion',
          description: 'Add index',
          priority: priority
        )
        expect(suggestion).to be_valid
      end
    end
  end

  describe 'associations' do
    let(:suggestion) { create(:optimization_suggestion) }

    it 'belongs to query_analysis' do
      expect(suggestion).to respond_to(:query_analysis)
      expect(suggestion.query_analysis).to be_a(QueryAnalysis)
    end

    it 'has access to app_profile through query_analysis' do
      expect(suggestion.query_analysis.app_profile).to be_an(AppProfile)
    end
  end

  describe 'scopes and methods' do
    let(:query_analysis) { create(:query_analysis) }

    before do
      create(:optimization_suggestion,
        query_analysis: query_analysis,
        suggestion_type: 'missing_index',
        title: 'Add index',
        priority: 3
      )
      create(:optimization_suggestion,
        query_analysis: query_analysis,
        suggestion_type: 'query_optimization',
        title: 'Optimize query',
        priority: 2
      )
      create(:optimization_suggestion,
        query_analysis: query_analysis,
        suggestion_type: 'n_plus_one',
        title: 'Fix N+1',
        priority: 4
      )
    end

    it 'can filter by priority' do
      high_priority = OptimizationSuggestion.where(priority: 3)
      expect(high_priority.count).to eq(1)
      expect(high_priority.first.suggestion_type).to eq('missing_index')
    end

    it 'can filter by suggestion_type' do
      index_suggestions = OptimizationSuggestion.where(suggestion_type: 'missing_index')
      expect(index_suggestions.count).to eq(1)
      expect(index_suggestions.first.priority).to eq(3)
    end

    it 'can order by priority' do
      suggestions = OptimizationSuggestion.order(priority: :desc)

      expect(suggestions.first.priority).to eq(4)
      expect(suggestions.last.priority).to eq(2)
    end

    it 'has priority_label method' do
      suggestion = OptimizationSuggestion.find_by(priority: 4)
      expect(suggestion.priority_label).to eq('Critical')

      suggestion = OptimizationSuggestion.find_by(priority: 2)
      expect(suggestion.priority_label).to eq('Medium')
    end
  end

  describe 'JSON serialization' do
    let(:suggestion) { create(:optimization_suggestion, metadata: { table: 'users', column: 'email' }) }

    it 'serializes metadata as JSON' do
      expect(suggestion.metadata).to be_a(Hash)
      expect(suggestion.metadata['table']).to eq('users')
      expect(suggestion.metadata['column']).to eq('email')
    end
  end

  describe 'factory' do
    it 'creates a valid optimization_suggestion' do
      suggestion = create(:optimization_suggestion)

      expect(suggestion).to be_valid
      expect(suggestion.suggestion_type).to be_present
      expect(suggestion.description).to be_present
      expect(suggestion.query_analysis).to be_present
      expect(suggestion.priority).to be_present
    end

    it 'creates suggestion with custom attributes' do
      suggestion = create(:optimization_suggestion,
        suggestion_type: 'missing_index',
        title: 'Composite Index',
        description: 'Add composite index on (user_id, created_at)',
        priority: 3
      )

      expect(suggestion.suggestion_type).to eq('missing_index')
      expect(suggestion.title).to eq('Composite Index')
      expect(suggestion.description).to include('composite index')
      expect(suggestion.priority).to eq(3)
      expect(suggestion.priority_label).to eq('High')
    end
  end
end

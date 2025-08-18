require 'rails_helper'

RSpec.describe QueryPattern, type: :model do
  describe 'validations' do
    it 'validates presence of pattern_type' do
      pattern = QueryPattern.new
      expect(pattern).not_to be_valid
      expect(pattern.errors[:pattern_type]).to include("can't be blank")
    end

    it 'validates presence of table_name' do
      pattern = QueryPattern.new(pattern_type: 'n_plus_one')
      expect(pattern).not_to be_valid
      expect(pattern.errors[:table_name]).to include("can't be blank")
    end

    it 'validates presence of first_seen' do
      pattern = QueryPattern.new(
        pattern_type: 'n_plus_one',
        table_name: 'users'
      )
      expect(pattern).not_to be_valid
      expect(pattern.errors[:first_seen]).to include("can't be blank")
    end

    it 'validates presence of last_seen' do
      pattern = QueryPattern.new(
        pattern_type: 'n_plus_one',
        table_name: 'users',
        first_seen: Time.current
      )
      expect(pattern).not_to be_valid
      expect(pattern.errors[:last_seen]).to include("can't be blank")
    end

    it 'validates numericality of frequency' do
      pattern = QueryPattern.new(
        pattern_type: 'n_plus_one',
        table_name: 'users',
        first_seen: Time.current,
        last_seen: Time.current,
        frequency: 0
      )
      expect(pattern).not_to be_valid
      expect(pattern.errors[:frequency]).to include('must be greater than 0')
    end

    it 'validates inclusion of pattern_type' do
      pattern = QueryPattern.new(
        pattern_type: 'invalid_type',
        table_name: 'users',
        first_seen: Time.current,
        last_seen: Time.current,
        frequency: 1
      )
      expect(pattern).not_to be_valid
      expect(pattern.errors[:pattern_type]).to include('is not included in the list')
    end
  end

  describe 'scopes and methods' do
    before do
      QueryPattern.record_pattern(type: 'n_plus_one', table: 'users', column: 'id')
      10.times { QueryPattern.record_pattern(type: 'n_plus_one', table: 'users', column: 'id') }

      QueryPattern.record_pattern(type: 'slow_query', table: 'posts', column: 'content')
      5.times { QueryPattern.record_pattern(type: 'slow_query', table: 'posts', column: 'content') }

      QueryPattern.record_pattern(type: 'missing_index', table: 'users', column: 'email')
      15.times { QueryPattern.record_pattern(type: 'missing_index', table: 'users', column: 'email') }
    end

    it 'can filter by pattern_type' do
      n_plus_one_patterns = QueryPattern.where(pattern_type: 'n_plus_one')
      expect(n_plus_one_patterns.count).to eq(1)
      expect(n_plus_one_patterns.first.table_name).to eq('users')
    end

    it 'can order by frequency' do
      patterns = QueryPattern.order(frequency: :desc)
      expect(patterns.first.frequency).to eq(16)
      expect(patterns.last.frequency).to eq(6)
    end

    it 'can find high frequency patterns' do
      high_frequency = QueryPattern.where('frequency >= ?', 10)
      expect(high_frequency.count).to eq(2)
    end

    it 'can use scopes' do
      expect(QueryPattern.n_plus_one.count).to eq(1)
      expect(QueryPattern.slow_queries.count).to eq(1)
      expect(QueryPattern.missing_indexes.count).to eq(1)
      expect(QueryPattern.frequent(10).count).to eq(2)
    end
  end

  describe 'pattern recording' do
    it 'records new patterns' do
      expect {
        QueryPattern.record_pattern(type: 'n_plus_one', table: 'users', column: 'id')
      }.to change(QueryPattern, :count).by(1)

      pattern = QueryPattern.last
      expect(pattern.pattern_type).to eq('n_plus_one')
      expect(pattern.table_name).to eq('users')
      expect(pattern.column_name).to eq('id')
      expect(pattern.frequency).to eq(1)
    end

    it 'increments frequency for existing patterns' do
      QueryPattern.record_pattern(type: 'n_plus_one', table: 'users', column: 'id')

      expect {
        QueryPattern.record_pattern(type: 'n_plus_one', table: 'users', column: 'id')
      }.not_to change(QueryPattern, :count)

      pattern = QueryPattern.last
      expect(pattern.frequency).to eq(2)
    end

    it 'generates consistent signatures' do
      sig1 = QueryPattern.generate_signature('n_plus_one', 'users', 'id')
      sig2 = QueryPattern.generate_signature('n_plus_one', 'users', 'id')

      expect(sig1).to eq(sig2)
      expect(sig1).to be_a(String)
      expect(sig1.length).to eq(64) # SHA256 hex length
    end
  end

  describe 'JSON serialization' do
    it 'serializes metadata as JSON' do
      pattern = QueryPattern.record_pattern(
        type: 'n_plus_one',
        table: 'users',
        column: 'id',
        metadata: { impact: 'high', severity: 'critical' }
      )

      expect(pattern.metadata).to be_a(Hash)
      expect(pattern.metadata['impact']).to eq('high')
      expect(pattern.metadata['severity']).to eq('critical')
    end
  end
end

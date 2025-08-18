class QueryPattern < ApplicationRecord
  validates :pattern_type, presence: true,
            inclusion: { in: %w[n_plus_one slow_query missing_index] }
  validates :table_name, presence: true
  validates :frequency, presence: true, numericality: { greater_than: 0 }
  validates :first_seen, presence: true
  validates :last_seen, presence: true
  validates :pattern_signature, presence: true, uniqueness: true

  before_validation :generate_pattern_signature, on: :create

  scope :n_plus_one, -> { where(pattern_type: 'n_plus_one') }
  scope :slow_queries, -> { where(pattern_type: 'slow_query') }
  scope :missing_indexes, -> { where(pattern_type: 'missing_index') }
  scope :frequent, ->(threshold = 5) { where('frequency >= ?', threshold) }
  scope :recent, -> { where('last_seen > ?', 24.hours.ago) }

  def self.record_pattern(type:, table:, column: nil, metadata: {})
    signature = generate_signature(type, table, column)

    pattern = find_or_initialize_by(pattern_signature: signature)

    if pattern.persisted?
      pattern.increment!(:frequency)
      pattern.update!(last_seen: Time.current)
    else
      pattern.assign_attributes(
        pattern_type: type,
        table_name: table,
        column_name: column,
        frequency: 1,
        first_seen: Time.current,
        last_seen: Time.current,
        metadata: metadata
      )
      pattern.save!
    end

    pattern
  end

  def self.generate_signature(type, table, column = nil)
    parts = [type, table]
    parts << column if column.present?
    Digest::SHA256.hexdigest(parts.join(':'))
  end

  private

  def generate_pattern_signature
    self.pattern_signature = self.class.generate_signature(
      pattern_type, table_name, column_name
    )
  end
end

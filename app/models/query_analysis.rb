class QueryAnalysis < ApplicationRecord
  belongs_to :app_profile
  has_many :optimization_suggestions, dependent: :destroy

  validates :sql_query, presence: true
  validates :analyzed_at, presence: true
  validates :query_type, inclusion: { in: %w[SELECT INSERT UPDATE DELETE] }

  before_save :generate_query_hash, :extract_table_name

  scope :slow_queries, ->(threshold = 200) { where('duration_ms > ?', threshold) }
  scope :by_table, ->(table_name) { where(table_name: table_name) }
  scope :recent, -> { where('analyzed_at > ?', 24.hours.ago) }

  def slow_query?(threshold = 200)
    duration_ms && duration_ms > threshold
  end

  def similar_queries
    return QueryAnalysis.none if query_hash.blank?

    QueryAnalysis.where(query_hash: query_hash)
                 .where.not(id: id)
                 .where(app_profile: app_profile)
  end

  private

  def generate_query_hash
    # Create a normalized hash of the query for similarity detection
    normalized_query = sql_query.gsub(/\d+/, '?')
                                .gsub(/'[^']*'/, '?')
                                .gsub(/\s+/, ' ')
                                .strip
                                .downcase
    self.query_hash = Digest::SHA256.hexdigest(normalized_query)
  end

  def extract_table_name
    return if sql_query.blank?

    # Simple table name extraction - can be enhanced with pg_query
    if sql_query.match(/(?:FROM|UPDATE|INTO)\s+([a-zA-Z_][a-zA-Z0-9_]*)/i)
      self.table_name = $1.downcase
    end
  end
end

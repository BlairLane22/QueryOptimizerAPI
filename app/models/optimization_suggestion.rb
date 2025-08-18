class OptimizationSuggestion < ApplicationRecord
  belongs_to :query_analysis
  has_one :app_profile, through: :query_analysis

  validates :suggestion_type, presence: true,
            inclusion: { in: %w[n_plus_one slow_query missing_index query_optimization] }
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, presence: true
  validates :priority, presence: true,
            inclusion: { in: 1..4 }  # 1=low, 2=medium, 3=high, 4=critical

  scope :by_type, ->(type) { where(suggestion_type: type) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :high_priority, -> { where(priority: [3, 4]) }
  scope :not_implemented, -> { where(implemented: false) }
  scope :implemented, -> { where(implemented: true) }

  def priority_label
    case priority
    when 1 then 'Low'
    when 2 then 'Medium'
    when 3 then 'High'
    when 4 then 'Critical'
    end
  end

  def mark_implemented!
    update!(implemented: true)
  end

  def self.create_for_analysis(analysis, suggestions_data)
    suggestions_data.map do |suggestion_data|
      create!(
        query_analysis: analysis,
        suggestion_type: suggestion_data[:type],
        title: suggestion_data[:title],
        description: suggestion_data[:description],
        sql_suggestion: suggestion_data[:sql_suggestion],
        priority: suggestion_data[:priority] || 2,
        metadata: suggestion_data[:metadata] || {}
      )
    end
  end
end

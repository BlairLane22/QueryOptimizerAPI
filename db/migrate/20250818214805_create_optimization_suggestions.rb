class CreateOptimizationSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :optimization_suggestions do |t|
      t.references :query_analysis, null: false, foreign_key: true
      t.string :suggestion_type, null: false  # 'n_plus_one', 'slow_query', 'missing_index', 'query_optimization'
      t.string :title, null: false
      t.text :description, null: false
      t.text :sql_suggestion
      t.integer :priority, default: 1  # 1=low, 2=medium, 3=high, 4=critical
      t.boolean :implemented, default: false
      t.json :metadata  # Additional suggestion-specific data

      t.timestamps
    end

    add_index :optimization_suggestions, :suggestion_type
    add_index :optimization_suggestions, :priority
    add_index :optimization_suggestions, :implemented
  end
end

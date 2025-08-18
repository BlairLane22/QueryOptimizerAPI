class CreateQueryPatterns < ActiveRecord::Migration[8.0]
  def change
    create_table :query_patterns do |t|
      t.string :pattern_type, null: false  # 'n_plus_one', 'slow_query', 'missing_index'
      t.string :table_name, null: false
      t.string :column_name
      t.integer :frequency, default: 1
      t.datetime :first_seen, null: false
      t.datetime :last_seen, null: false
      t.string :pattern_signature  # Unique identifier for the pattern
      t.json :metadata  # Additional pattern-specific data

      t.timestamps
    end

    add_index :query_patterns, :pattern_type
    add_index :query_patterns, :table_name
    add_index :query_patterns, :pattern_signature, unique: true
    add_index :query_patterns, :frequency
    add_index :query_patterns, [:pattern_type, :table_name]
  end
end

class CreateQueryAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :query_analyses do |t|
      t.references :app_profile, null: false, foreign_key: true
      t.text :sql_query, null: false
      t.integer :duration_ms
      t.string :table_name
      t.string :query_type
      t.datetime :analyzed_at, null: false
      t.string :query_hash  # For detecting similar queries
      t.json :parsed_data   # Store parsed query structure

      t.timestamps
    end

    add_index :query_analyses, :analyzed_at
    add_index :query_analyses, :table_name
    add_index :query_analyses, :query_type
    add_index :query_analyses, :query_hash
    add_index :query_analyses, :duration_ms
  end
end

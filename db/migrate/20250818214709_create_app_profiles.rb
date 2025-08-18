class CreateAppProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :app_profiles do |t|
      t.string :name, null: false
      t.string :api_key_digest, null: false

      t.timestamps
    end

    add_index :app_profiles, :api_key_digest, unique: true
    add_index :app_profiles, :name
  end
end

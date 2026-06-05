class CreateJobProfileRisks < ActiveRecord::Migration[8.1]
  def change
    create_table :job_profile_risks do |t|
      t.references :job_profile, null: false, foreign_key: true
      t.integer :category, null: false
      t.string :factor, null: false
      t.integer :exposure_level
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :job_profile_risks, [:job_profile_id, :position]
  end
end

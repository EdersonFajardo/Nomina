class CreateJobProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :job_profiles do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code
      t.string :immediate_boss
      t.string :people_in_charge
      t.text :education
      t.text :training
      t.text :experience
      t.text :authority
      t.text :skills
      t.text :position_objectives
      t.text :hse_objectives
      t.text :main_responsibility
      t.text :own_functions
      t.text :sig_responsibilities
      t.string :elaborated_by
      t.string :approved_by
      t.string :form_code, default: "RH-F-14"
      t.string :form_version
      t.date :form_date

      t.timestamps
    end

    add_index :job_profiles, [:company_id, :name], unique: true
  end
end

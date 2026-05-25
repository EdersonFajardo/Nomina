class CreateEmailAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :email_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :email, null: false
      t.string :provider, null: false, default: "gmail"
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.string :scopes
      t.string :history_id
      t.string :sync_status, null: false, default: "pending"
      t.datetime :last_synced_at
      t.text :last_sync_error

      t.timestamps
    end

    add_index :email_accounts, [:user_id, :email], unique: true
  end
end

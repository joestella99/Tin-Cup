class AddAccountsAndTripMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :recovery_code_digest, null: false
      t.timestamps
    end
    add_index :users, :email_address, unique: true
    create_table :logins do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :expires_at, null: false
      t.timestamps
    end
    create_table :memberships do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "scorer"
      t.timestamps
    end
    add_index :memberships, [ :trip_id, :user_id ], unique: true
    add_index :memberships, :trip_id, unique: true, where: "role = 'owner'", name: 'one_owner_per_trip'
    add_check_constraint :memberships, "role IN ('owner', 'scorer')", name: 'memberships_valid_role'
    create_table :invitations do |t|
      t.references :trip, null: false, foreign_key: true
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
  end
end

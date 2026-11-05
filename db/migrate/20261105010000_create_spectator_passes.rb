class CreateSpectatorPasses < ActiveRecord::Migration[8.1]
  def change
    create_table :spectator_passes do |t|
      t.references :trip, null: false, foreign_key: true
      t.datetime :revoked_at
      t.timestamps
    end
  end
end

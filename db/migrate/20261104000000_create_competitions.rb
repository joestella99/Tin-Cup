class CreateCompetitions < ActiveRecord::Migration[8.1]
  def change
    create_table :trips do |t|
      t.string :name, null: false
      t.string :destination, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.timestamps
    end
    create_table :players do |t|
      t.references :trip, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :playing_handicap, null: false, default: 0
      t.timestamps
    end
    add_index :players, [ :trip_id, :name ], unique: true
    create_table :rounds do |t|
      t.references :trip, null: false, foreign_key: true
      t.string :course, null: false
      t.date :plays_on, null: false
      t.timestamps
    end
    create_table :scores do |t|
      t.references :round, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :gross, null: false
      t.timestamps
    end
    add_index :scores, [ :round_id, :player_id ], unique: true
    add_check_constraint :scores, 'gross > 0', name: 'scores_positive_gross'
    add_check_constraint :players, 'playing_handicap BETWEEN -10 AND 54', name: 'players_handicap_range'
  end
end

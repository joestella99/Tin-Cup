class AddTripCups < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.references :trip, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :teams, [ :trip_id, :name ], unique: true
    add_reference :players, :team, foreign_key: true
    add_column :rounds, :scoring_mode, :string, default: "total", null: false
    add_column :rounds, :course_confirmed, :boolean, default: false, null: false
    create_table :holes do |t|
      t.references :round, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :par, null: false, default: 4
      t.integer :stroke_index, null: false
      t.timestamps
    end
    add_index :holes, [ :round_id, :number ], unique: true
    add_index :holes, [ :round_id, :stroke_index ], unique: true
    create_table :hole_scores do |t|
      t.references :hole, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :strokes, null: false
      t.timestamps
    end
    add_index :hole_scores, [ :hole_id, :player_id ], unique: true
    add_check_constraint :hole_scores, 'strokes BETWEEN 1 AND 30', name: 'hole_scores_strokes_range'
    add_check_constraint :holes, 'number BETWEEN 1 AND 18 AND par BETWEEN 3 AND 6 AND stroke_index BETWEEN 1 AND 18', name: 'holes_valid_ranges'
    create_table :matches do |t|
      t.references :round, null: false, foreign_key: true
      t.references :home_player, null: false, foreign_key: { to_table: :players }
      t.references :away_player, null: false, foreign_key: { to_table: :players }
      t.timestamps
    end
    add_check_constraint :matches, 'home_player_id <> away_player_id', name: 'matches_distinct_players'
  end
end

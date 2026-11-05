class AddCourseTeeScorecards < ActiveRecord::Migration[8.1]
  def change
    add_column :golf_courses, :tee_options, :jsonb, default: [], null: false
    add_column :rounds, :tee_name, :string
    add_column :holes, :yardage, :integer
    add_check_constraint :holes, "yardage IS NULL OR (yardage >= 20 AND yardage <= 800)", name: "holes_realistic_yardage"
  end
end

class CreateGolfCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :golf_courses do |t|
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :city
      t.string :state
      t.string :country
      t.string :address
      t.string :course_type
      t.string :website
      t.integer :holes_count
      t.integer :par_total
      t.jsonb :scorecard, null: false, default: []
      t.timestamps
    end

    add_index :golf_courses, :external_id, unique: true
    add_index :golf_courses, :name
    add_reference :rounds, :golf_course, foreign_key: true, index: true
  end
end

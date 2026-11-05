require "test_helper"

class GolfCourseTest < ActiveSupport::TestCase
  def valid_card
    (1..18).map { |n| { "number" => n, "par" => 4, "stroke_index" => n } }
  end

  test "only a complete 18-hole card with unique handicap indexes can auto confirm" do
    course = GolfCourse.create!(name: "Sample Links", external_id: "00000000-0000-0000-0000-000000000001", scorecard: valid_card)
    assert course.complete_scorecard?
    assert_equal 18, course.scorecard_entries.size
    course.update!(scorecard: valid_card.take(17))
    assert_not course.complete_scorecard?
    course.update!(scorecard: valid_card.map { |hole| hole.merge("stroke_index" => 1) })
    assert_not course.complete_scorecard?
  end

  test "import adapts upstream card and leaves missing data unconfirmed" do
    raw = { "id" => "00000000-0000-0000-0000-000000000002", "course_name" => "Fairways",
      "state" => "NC", "city" => "Pinehurst", "holes" => 18, "par_total" => 72,
      "scorecard" => (1..18).map { |n| { "hole_number" => n, "par" => 4, "handicap_index" => n } } }
    course = GolfCourse.import!(raw)
    assert_equal "Fairways", course.name
    assert course.complete_scorecard?
    assert_equal 72, course.par_total
    assert_equal "Pinehurst, NC", course.location
  end
end

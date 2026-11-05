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


class GolfCourseTeeTest < ActiveSupport::TestCase
  test "imports real tee yardages and full card without inventing absent values" do
    raw = { "id" => "00000000-0000-0000-0000-000000000006",
      "course_name" => "Green Links", "holes" => 18, "par_total" => 72,
      "tee_options" => [ { "tee_name" => "Blue", "rating" => 72.1, "slope" => 127, "total_yardage" => 6500 },
                         { "tee_name" => "White" } ],
      "scorecard" => (1..18).map do |n|
        { "hole_number" => n, "par" => 4, "handicap_index" => n,
          "yardages" => { "Blue" => 380 + n, "White" => 320 + n } }
      end }
    course = GolfCourse.import!(raw)
    assert_equal [ "Blue", "White" ], course.tee_names
    assert course.complete_scorecard?
    assert_equal 381, course.yardage_for(course.scorecard_entries.first, "Blue")
    assert_equal 321, course.yardage_for(course.scorecard_entries.first, "White")
    round_trip = build_trip
    round = round_trip.rounds.create!(course: course.name, golf_course: course, tee_name: "Blue",
      plays_on: round_trip.starts_on, scoring_mode: :hole_by_hole)
    round.copy_library_scorecard!
    assert round.reload.course_confirmed?
    assert_equal 381, round.holes.find_by!(number: 1).yardage

    # A later refreshed record does not change the actual round's snapshot.
    GolfCourse.import!(raw.merge("scorecard" => raw["scorecard"].take(4), "tee_options" => []))
    assert course.reload.complete_scorecard?
    assert_equal [ "Blue", "White" ], course.tee_names
    assert_equal 381, round.holes.find_by!(number: 1).yardage
  end
end

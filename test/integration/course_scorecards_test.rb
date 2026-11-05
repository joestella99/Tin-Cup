require "test_helper"

class CourseScorecardsTest < ActionDispatch::IntegrationTest
  setup do
    @old_password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "local-test-only"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    @trip = build_trip
    @id = "00000000-0000-0000-0000-000000000007"
    @raw = { "id" => @id, "course_name" => "Test Links", "holes" => 18,
      "scorecard" => (1..18).map { |n| { "hole_number" => n, "par" => 4, "handicap_index" => n, "yardages" => { "Blue" => 350 + n } } },
      "tee_options" => [ { "tee_name" => "Blue", "rating" => 70.5, "slope" => 120 } ] }
  end
  teardown { ENV["ORGANIZER_PASSWORD"] = @old_password }

  test "imported course has a usable 18 hole scorecard and carries tee yardages into the round" do
    api_stub { post trip_golf_courses_path(@trip), params: { external_id: @id } }
    course = GolfCourse.find_by!(external_id: @id)
    get trip_golf_course_path(@trip, course), params: { tee: "Blue" }
    assert_response :success
    assert_select ".course-db-scorecard tbody tr", count: 18
    assert_select ".course-db-scorecard", text: /351/
    get trip_path(@trip, selected_course_id: course.id)
    assert_select "[data-controller='course-tee-picker']"
    post trip_rounds_path(@trip), params: { round: { golf_course_id: course.id, tee_name: "Blue",
      plays_on: @trip.starts_on, scoring_mode: "hole_by_hole" } }
    assert_redirected_to trip_path(@trip)
    round = @trip.rounds.last
    assert round.course_confirmed?
    assert_equal "Blue", round.tee_name
    assert_equal 351, round.holes.find_by!(number: 1).yardage
    get edit_trip_round_course_card_path(@trip, round)
    assert_response :success
    assert_includes response.body, "351"
  end

  test "refresh restores data without rewriting existing rounds" do
    course = GolfCourse.import!(@raw)
    round = @trip.rounds.create!(course: course.name, golf_course: course, tee_name: "Blue",
      plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    round.copy_library_scorecard!
    revised = @raw.deep_dup
    revised["scorecard"][0]["yardages"]["Blue"] = 399
    api_stub(revised) { post refresh_trip_golf_course_path(@trip, course) }
    assert_equal 399, course.reload.yardage_for(course.scorecard_entries.first, "Blue")
    assert_equal 351, round.holes.find_by!(number: 1).yardage
  end

  private

  def api_stub(data = @raw)
    original = OpenGolfApi.method(:full_course)
    OpenGolfApi.define_singleton_method(:full_course) { |_id| data }
    yield
  ensure
    OpenGolfApi.define_singleton_method(:full_course, original)
  end
end

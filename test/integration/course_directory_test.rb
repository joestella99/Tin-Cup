require "test_helper"

class CourseDirectoryTest < ActionDispatch::IntegrationTest
  setup do
    @old_password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "local-test-only"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    @trip = build_trip
    @source_id = "00000000-0000-0000-0000-000000000003"
    @source = { "id" => @source_id, "course_name" => "Pinehurst Test Course", "city" => "Pinehurst",
      "state" => "NC", "country" => "US", "par_total" => 72, "holes" => 18,
      "scorecard" => (1..18).map { |n| { "hole_number" => n, "par" => 4, "handicap_index" => n } } }
  end

  teardown { ENV["ORGANIZER_PASSWORD"] = @old_password }

  test "search, import and schedule copy a complete source scorecard into new round" do
    OpenGolfApi.stub(:search, [@source]) do
      get trip_golf_courses_path(@trip), params: { q: "Pinehurst" }
      assert_response :success
      assert_select ".course-db-card h3", text: "Pinehurst Test Course"
    end

    OpenGolfApi.stub(:course, @source) do
      post trip_golf_courses_path(@trip), params: { external_id: @source_id }
    end
    imported = GolfCourse.find_by!(external_id: @source_id)
    assert_redirected_to trip_path(@trip, selected_course_id: imported.id, anchor: "schedule-round")

    post trip_rounds_path(@trip), params: { round: { golf_course_id: imported.id, course: "",
      plays_on: @trip.starts_on, scoring_mode: "hole_by_hole" } }
    round = @trip.rounds.last
    assert_redirected_to trip_path(@trip)
    assert_equal "Pinehurst Test Course", round.course
    assert_equal imported, round.golf_course
    assert round.course_confirmed?
    assert_equal (1..18).to_a, round.holes.order(:number).pluck(:stroke_index)

    imported.update!(scorecard: [])
    assert_equal 18, round.holes.count
    assert round.reload.course_confirmed?
    get trip_golf_course_path(@trip, imported)
    assert_response :success
  end

  test "incomplete source scorecards require manual confirmation" do
    source = @source.merge("scorecard" => @source["scorecard"].take(5))
    imported = GolfCourse.import!(source)
    post trip_rounds_path(@trip), params: { round: { golf_course_id: imported.id, plays_on: @trip.starts_on,
      scoring_mode: "hole_by_hole" } }
    round = @trip.rounds.last
    assert_not round.course_confirmed?
    assert_equal 18, round.holes.count
  end

  test "upstream failure keeps saved directory browsable" do
    saved = GolfCourse.import!(@source)
    OpenGolfApi.stub(:search, ->(_q) { raise OpenGolfApi::Unavailable, "down" }) do
      get trip_golf_courses_path(@trip), params: { q: "Pinehurst" }
      assert_response :success
      assert_select ".course-db-card h3", text: saved.name
      assert_select ".course-db-attribution", count: 1
    end
  end
end

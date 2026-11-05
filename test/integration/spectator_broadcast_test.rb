require "test_helper"

class SpectatorBroadcastTest < ActionDispatch::IntegrationTest
  setup do
    @password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "test-only-captain-password"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    @trip = build_trip(name: "Sandbaggers Cup")
    red = @trip.teams.create!(name: "Red Team")
    blue = @trip.teams.create!(name: "Blue Team")
    @a = @trip.players.create!(name: "Joe", team: red, playing_handicap: 0)
    @b = @trip.players.create!(name: "Matt", team: blue, playing_handicap: 0)
    @round = @trip.rounds.create!(course: "Pinehurst No. 2", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
    @round.holes.first.hole_scores.create!(player: @a, strokes: 3)
    @round.holes.first.hole_scores.create!(player: @b, strokes: 5)
  end

  teardown { ENV["ORGANIZER_PASSWORD"] = @password }

  test "organizer enables a private broadcast, and non-members watch without a login" do
    post trip_spectator_passes_path(@trip)
    assert_redirected_to trip_path(@trip, view: "manage", anchor: "spectator-access")
    pass = @trip.spectator_passes.active.first
    assert pass
    get trip_path(@trip, view: "manage")
    assert_select "#watch-link[value]"
    assert_select ".spectator-manage"
    delete session_path

    get watch_path(pass.share_token)
    assert_response :success
    assert_equal "noindex, nofollow, noarchive", response.headers["X-Robots-Tag"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "turbo-frame#spectator_live[src]"
    assert_select "form", count: 0
    get watch_live_path(pass.share_token)
    assert_response :success
    assert_select "turbo-frame#spectator_live"
    assert_select ".live-score-row", count: 2
    assert_select ".watch-cup-row", count: 2
    assert_includes response.body, "Pinehurst No. 2"
    assert_not_includes response.body, "trip-round"
    get trip_path(@trip)
    assert_redirected_to new_session_path
  end

  test "broadcasts are off by default and revocation immediately blocks old links" do
    get watch_path("not-a-real-token")
    assert_response :not_found
    post trip_spectator_passes_path(@trip)
    pass = @trip.spectator_passes.active.first
    token = pass.share_token
    delete trip_spectator_pass_path(@trip, pass)
    assert pass.reload.revoked_at
    get watch_path(token)
    assert_response :not_found
    get watch_live_path(token)
    assert_response :not_found
    post trip_spectator_passes_path(@trip)
    new_token = @trip.spectator_passes.active.first.share_token
    assert_not_equal token, new_token
    get watch_path(new_token)
    assert_response :success
  end
end

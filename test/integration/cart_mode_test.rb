require "test_helper"

class CartModeTest < ActionDispatch::IntegrationTest
  setup do
    @password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "cart-mode-tests-only"
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    @trip = build_trip(name: "Cart Championship")
    @red = @trip.teams.create!(name: "Red")
    @blue = @trip.teams.create!(name: "Blue")
    @joe = @trip.players.create!(name: "Joe", team: @red, playing_handicap: 6)
    @matt = @trip.players.create!(name: "Matt", team: @blue, playing_handicap: 12)
    @round = @trip.rounds.create!(course: "Pinehurst No. 2", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @round.update!(course_confirmed: true)
    @first = @round.holes.find_by!(number: 1)
  end

  teardown { ENV["ORGANIZER_PASSWORD"] = @password }

  test "pick a player once then open the next unfinished hole every visit" do
    get cart_trip_round_path(@trip, @round)
    assert_response :success
    assert_select ".cart-pick h1", text: /Whose card/
    assert_select ".cart-player-card", count: 2

    get cart_trip_round_path(@trip, @round, player_id: @joe.id)
    assert_response :success
    assert_select ".cart-mode-page" , count: 0
    assert_select ".cart-roundbar", text: /Pinehurst/
    assert_select ".cart-score-button", count: 7
    assert_select ".cart-score-button[name='strokes[#{@joe.id}]'][value='4']", count: 1
    assert_select ".cart-hole-link.active", text: "1"
    assert_select ".cart-score-form"

    # Browser session remembers the player, without a long account setup.
    get cart_trip_round_path(@trip, @round)
    assert_response :success
    assert_select ".cart-score-button[name='strokes[#{@joe.id}]']", minimum: 1
  end

  test "one tap saves a birdie, advances, celebrates and allows a correction" do
    @first.hole_scores.create!(player: @matt, strokes: 5)
    @round.matches.create!(home_player: @joe, away_player: @matt)

    patch trip_round_hole_hole_scores_path(@trip, @round, @first),
      params: { player_id: @joe.id, cart_mode: "1", strokes: { @joe.id.to_s => "3" } }
    assert_redirected_to cart_trip_round_path(@trip, @round, player_id: @joe.id, hole: 2)
    assert_equal 3, @first.hole_scores.find_by!(player: @joe).strokes
    assert_equal 5, @first.hole_scores.find_by!(player: @matt).strokes

    follow_redirect!
    assert_response :success
    assert_select ".cart-toast-highlight", text: /Birdie! Saved/
    assert_select ".cart-toast-edit[href*='hole=1']"
    assert_select ".cart-hole-link.active", text: "2"
    assert_select ".cart-rivalry", text: /1 UP/
    assert_select ".cart-stats", text: /NET TO PAR/

    get cart_trip_round_path(@trip, @round, player_id: @joe.id, hole: 1)
    assert_select ".cart-saved-chip", text: /SAVED 3/
    patch trip_round_hole_hole_scores_path(@trip, @round, @first),
      params: { player_id: @joe.id, cart_mode: "1", strokes: { @joe.id.to_s => "4" } }
    assert_equal 4, @first.hole_scores.find_by!(player: @joe).strokes
    assert_equal 5, @first.hole_scores.find_by!(player: @matt).strokes
  end

  test "custom scores work and missing input does not silently clear a card" do
    patch trip_round_hole_hole_scores_path(@trip, @round, @first),
      params: { player_id: @joe.id, cart_mode: "1", save_custom: "1",
        custom_strokes: "8", strokes: { @matt.id.to_s => "2" } }
    assert_redirected_to cart_trip_round_path(@trip, @round, player_id: @joe.id, hole: 2)
    assert_equal 8, @first.hole_scores.find_by!(player: @joe).strokes
    assert_not @first.hole_scores.exists?(player: @matt)

    # A missing score must fail rather than accidentally wiping the record.
    assert_raises(ActionController::BadRequest) do
      patch trip_round_hole_hole_scores_path(@trip, @round, @first),
        params: { player_id: @joe.id, cart_mode: "1", save_custom: "1" }
    end
    assert_equal 8, @first.hole_scores.find_by!(player: @joe).strokes

    patch trip_round_hole_hole_scores_path(@trip, @round, @first),
      params: { player_id: @joe.id, cart_mode: "1", strokes: { @joe.id.to_s => "" } }
    assert_redirected_to cart_trip_round_path(@trip, @round, player_id: @joe.id, hole: 1)
    assert_not @first.hole_scores.exists?(player: @joe)
    follow_redirect!
    assert_select ".cart-toast", text: /Score cleared/
  end

  test "forged cart payload cannot change the playing partner's score" do
    @first.hole_scores.create!(player: @matt, strokes: 5)
    patch trip_round_hole_hole_scores_path(@trip, @round, @first),
      params: { player_id: @joe.id, cart_mode: "1",
        strokes: { @joe.id.to_s => "3", @matt.id.to_s => "1" } }
    assert_redirected_to cart_trip_round_path(@trip, @round, player_id: @joe.id, hole: 2)
    assert_equal 5, @first.hole_scores.find_by!(player: @matt).strokes
    assert_equal 3, @first.hole_scores.find_by!(player: @joe).strokes
  end

  test "final hole shows finished screen and completed net totals" do
    @round.holes.order(:number).first(17).each do |hole|
      hole.hole_scores.create!(player: @joe, strokes: hole.par)
    end
    get cart_trip_round_path(@trip, @round, player_id: @joe.id)
    assert_response :success
    assert_select ".cart-hole-link.active", text: "18"
    patch trip_round_hole_hole_scores_path(@trip, @round, @round.holes.find_by!(number: 18)),
      params: { player_id: @joe.id, cart_mode: "1", strokes: { @joe.id.to_s => "4" } }
    assert_redirected_to cart_trip_round_path(@trip, @round, player_id: @joe.id)
    follow_redirect!
    assert_select ".cart-finished", text: /That's a wrap/
    assert_select ".cart-stats", text: /NET TO PAR/
  end

  test "cart mode is protected and requires a confirmed hole-by-hole round" do
    totals = @trip.rounds.create!(course: "Totals", plays_on: @trip.starts_on, scoring_mode: :total)
    get cart_trip_round_path(@trip, totals)
    assert_redirected_to trip_round_path(@trip, totals)
    @round.update!(course_confirmed: false)
    get cart_trip_round_path(@trip, @round)
    assert_redirected_to trip_round_path(@trip, @round)
    @round.update!(course_confirmed: true)

    other_trip = build_trip(name: "Private Other Trip")
    other_player = other_trip.players.create!(name: "Stranger", playing_handicap: 0)
    get cart_trip_round_path(@trip, @round, player_id: other_player.id)
    assert_response :not_found

    delete session_path
    get cart_trip_round_path(@trip, @round)
    assert_redirected_to new_session_path
  end

  test "trip main screen links directly to cart mode for a ready round" do
    get trip_path(@trip, view: "play")
    assert_response :success
    assert_select "a[href='#{cart_trip_round_path(@trip, @round)}']", text: /Cart Mode/
    get trip_path(@trip)
    assert_response :success
    assert_select ".hq-next-card a[href='#{cart_trip_round_path(@trip, @round)}']"
  end
end

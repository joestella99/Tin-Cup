require "test_helper"

class DeletionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = make_user("Captain", "captain@example.test")
    @buddy = make_user("Buddy", "buddy-delete@example.test")
    @outsider = make_user("Outsider", "outsider-delete@example.test")
    @trip = build_trip(name: "Sandbaggers Invitational")
    @trip.memberships.create!(user: @owner, role: :owner)
    @trip.memberships.create!(user: @buddy, role: :scorer)

    @red = @trip.teams.create!(name: "Red")
    @blue = @trip.teams.create!(name: "Blue")
    @a = @trip.players.create!(name: "Captain Joe", team: @red, playing_handicap: 8)
    @b = @trip.players.create!(name: "Buddy Matt", team: @blue, playing_handicap: 12)
    @hole_round = @trip.rounds.create!(course: "Pinehurst No. 2", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    @hole_round.update!(course_confirmed: true)
    @total_round = @trip.rounds.create!(course: "Pine Needles", plays_on: @trip.starts_on + 1.day, scoring_mode: :total)
    hole = @hole_round.holes.find_by!(number: 1)
    @a_hole_score = hole.hole_scores.create!(player: @a, strokes: 4)
    @b_hole_score = hole.hole_scores.create!(player: @b, strokes: 5)
    @a_total_score = @total_round.scores.create!(player: @a, gross: 81)
    @b_total_score = @total_round.scores.create!(player: @b, gross: 83)
    @match = @hole_round.matches.create!(home_player: @a, away_player: @b)
    sign_in(@owner)
  end

  def make_user(name, email)
    User.create!(name: name, email_address: email, password: "secure-password-for-tests",
      password_confirmation: "secure-password-for-tests")
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "secure-password-for-tests" }
    assert_redirected_to trips_path
  end

  test "captain can delete a golfer and dependent scores and matches without disturbing the rest" do
    get trip_path(@trip, view: "manage")
    assert_response :success
    assert_select "#manage-players form[action='#{trip_player_path(@trip, @a)}']"
    delete trip_player_path(@trip, @a)
    assert_redirected_to trip_path(@trip, view: "manage", anchor: "manage-players")
    assert_not Player.exists?(@a.id)
    assert_not HoleScore.exists?(@a_hole_score.id)
    assert_not Score.exists?(@a_total_score.id)
    assert_not Match.exists?(@match.id)
    assert Player.exists?(@b.id)
    assert HoleScore.exists?(@b_hole_score.id)
    assert Score.exists?(@b_total_score.id)
    assert Round.exists?(@hole_round.id)
    assert Team.exists?(@red.id)
  end

  test "captain can remove a played round and all its content while keeping other rounds and scores" do
    get trip_path(@trip, view: "manage")
    assert_select "#manage-rounds form[action='#{trip_round_path(@trip, @hole_round)}']"
    delete trip_round_path(@trip, @hole_round)
    assert_redirected_to trip_path(@trip, view: "manage", anchor: "manage-rounds")
    assert_not Round.exists?(@hole_round.id)
    assert_not HoleScore.exists?(@a_hole_score.id)
    assert_not HoleScore.exists?(@b_hole_score.id)
    assert_not Match.exists?(@match.id)
    assert Round.exists?(@total_round.id)
    assert Score.exists?(@a_total_score.id)
    assert Score.exists?(@b_total_score.id)
    assert Player.exists?(@a.id)
  end

  test "deleting a team unassigns golfers, removes invalidated matches, but preserves all scores" do
    get trip_path(@trip, view: "manage")
    assert_select "#manage-teams form[action='#{trip_team_path(@trip, @red)}']"
    delete trip_team_path(@trip, @red)
    assert_redirected_to trip_path(@trip, view: "manage", anchor: "manage-teams")
    assert_not Team.exists?(@red.id)
    assert_nil @a.reload.team
    assert_equal @blue, @b.reload.team
    assert_not Match.exists?(@match.id)
    assert HoleScore.exists?(@a_hole_score.id)
    assert HoleScore.exists?(@b_hole_score.id)
    assert Score.exists?(@a_total_score.id)
  end

  test "trip deletion requires the exact trip name and clears all associated data" do
    invite = @trip.invitations.create!(expires_at: 3.days.from_now)
    spectator = @trip.spectator_passes.create!
    get delete_confirmation_trip_path(@trip)
    assert_response :success
    assert_select "input[name='confirmation_name']"
    assert_select "form[action='#{trip_path(@trip)}']"
    delete trip_path(@trip), params: { confirmation_name: "Not the correct trip" }
    assert_response :unprocessable_entity
    assert Trip.exists?(@trip.id)
    delete trip_path(@trip)
    assert_response :unprocessable_entity
    assert Trip.exists?(@trip.id)

    delete trip_path(@trip), params: { confirmation_name: @trip.name }
    assert_redirected_to trips_path
    assert_not Trip.exists?(@trip.id)
    assert_not Player.exists?(@a.id)
    assert_not Round.exists?(@hole_round.id)
    assert_not Score.exists?(@a_total_score.id)
    assert_not HoleScore.exists?(@b_hole_score.id)
    assert_not Team.exists?(@blue.id)
    assert_not Membership.exists?(trip_id: @trip.id)
    assert_not Invitation.exists?(invite.id)
    assert_not SpectatorPass.exists?(spectator.id)
    assert User.exists?(@owner.id)
    assert User.exists?(@buddy.id)
  end

  test "members and outsiders cannot delete or see captain-only deletion screens" do
    delete session_path
    sign_in(@buddy)
    get trip_path(@trip, view: "manage")
    assert_response :success
    assert_select ".management-area", count: 0
    assert_select ".danger-button", count: 0
    get delete_confirmation_trip_path(@trip)
    assert_response :not_found
    delete trip_path(@trip), params: { confirmation_name: @trip.name }
    assert_response :not_found
    delete trip_player_path(@trip, @a)
    assert_response :not_found
    delete trip_round_path(@trip, @hole_round)
    assert_response :not_found
    delete trip_team_path(@trip, @red)
    assert_response :not_found
    assert Trip.exists?(@trip.id)
    assert Player.exists?(@a.id)
    assert Round.exists?(@hole_round.id)
    assert Team.exists?(@red.id)

    delete session_path
    sign_in(@outsider)
    delete trip_path(@trip), params: { confirmation_name: @trip.name }
    assert_response :not_found
    delete trip_player_path(@trip, @a)
    assert_response :not_found
    delete trip_round_path(@trip, @hole_round)
    assert_response :not_found
    delete trip_team_path(@trip, @red)
    assert_response :not_found
    assert Trip.exists?(@trip.id)
  end

  test "no deletion endpoints accept anonymous requests" do
    delete session_path
    delete trip_path(@trip), params: { confirmation_name: @trip.name }
    assert_redirected_to new_session_path
    delete trip_player_path(@trip, @a)
    assert_redirected_to new_session_path
    delete trip_round_path(@trip, @hole_round)
    assert_redirected_to new_session_path
    delete trip_team_path(@trip, @red)
    assert_redirected_to new_session_path
  end
end

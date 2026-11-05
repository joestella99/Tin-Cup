require "test_helper"

class AccountAccessTest < ActionDispatch::IntegrationTest
  setup do
    @previous_password = ENV["ORGANIZER_PASSWORD"]
    ENV["ORGANIZER_PASSWORD"] = "legacy-local-test-password"
    @owner = make_user("Owner", "owner@example.test")
    @buddy = make_user("Buddy", "buddy@example.test")
    @outsider = make_user("Other", "other@example.test")
    @trip = Trip.create!(name: "Private Cup", destination: "Pinehurst", starts_on: "2027-05-01", ends_on: "2027-05-03")
    @trip.memberships.create!(user: @owner, role: :owner)
    @round = @trip.rounds.create!(course: "Course", plays_on: @trip.starts_on)
    @player = @trip.players.create!(name: "Player", playing_handicap: 12)
  end
  teardown { ENV["ORGANIZER_PASSWORD"] = @previous_password }

  def make_user(name, email)
    User.create!(name: name, email_address: email, password: "test-password-long", password_confirmation: "test-password-long")
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "test-password-long" }
    assert_redirected_to trips_path
  end

  test "public account and sign-in forms use a CSRF-compatible same-origin referrer policy" do
    get new_registration_path
    assert_response :success
    assert_equal "same-origin", response.headers["Referrer-Policy"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "form[action='#{registration_path}'][method='post']"
    assert_select "input[name='authenticity_token']"

    get new_session_path
    assert_response :success
    assert_equal "same-origin", response.headers["Referrer-Policy"]

    post registration_path, params: { user: {
      name: "Browser Signup", email_address: "browser@example.test",
      password: "a-long-browser-password", password_confirmation: "a-long-browser-password"
    } }, headers: { "HTTP_ORIGIN" => "http://www.example.com" }
    assert_response :created
    assert User.exists?(email_address: "browser@example.test")
  end

  test "signup shows recovery code once and creates a private organizer-owned trip" do
    get new_registration_path
    assert_response :success
    post registration_path, params: { user: { name: "Joe", email_address: "JOE@example.test", password: "new-password-long", password_confirmation: "new-password-long" } }
    assert_response :created
    assert_select "#recovery-code[value]"
    assert_equal "no-store", response.headers["Cache-Control"]
    user = User.find_by!(email_address: "joe@example.test")
    post trips_path, params: { trip: { name: "My Annual", destination: "NC", starts_on: "2027-06-01", ends_on: "2027-06-03" } }
    trip = Trip.find_by!(name: "My Annual")
    assert_equal user, trip.ownership.user
    get trips_path
    assert_response :success
    assert_includes response.body, "My Annual"
    assert_not_includes response.body, "Private Cup"
  end

  test "outsiders cannot discover trips or write nested resources" do
    sign_in(@outsider)
    get trips_path
    assert_not_includes response.body, "Private Cup"
    get trip_path(@trip)
    assert_response :not_found
    get trip_round_path(@trip, @round)
    assert_response :not_found
    post trip_teams_path(@trip), params: { team: { name: "Hacker" } }
    assert_response :not_found
    patch trip_round_scorecard_path(@trip, @round), params: { scores: { @player.id.to_s => 85 } }
    assert_response :not_found
    assert_empty @round.scores
  end

  test "buddy joins with an invitation and can score but cannot manage setup" do
    invitation = @trip.invitations.create!(expires_at: 1.day.from_now)
    sign_in(@buddy)
    get join_path(invitation.join_token)
    assert_response :success
    post join_path(invitation.join_token), params: { role: "owner" }
    assert_redirected_to trip_path(@trip)
    membership = @trip.memberships.find_by!(user: @buddy)
    assert membership.scorer?
    post join_path(invitation.join_token)
    assert_equal 1, @trip.memberships.where(user: @buddy).count
    get trip_path(@trip)
    assert_response :success
    assert_not_includes response.body, "Create invite link"
    get trip_round_path(@trip, @round)
    assert_response :success
    patch trip_round_scorecard_path(@trip, @round), params: { scores: { @player.id.to_s => 85 } }
    assert_equal 73, @round.scores.first.net
    post trip_players_path(@trip), params: { player: { name: "Unauthorized", playing_handicap: 0 } }
    assert_response :not_found
    patch trip_player_path(@trip, @player), params: { player: { team_id: nil } }
    assert_response :not_found
    post trip_teams_path(@trip), params: { team: { name: "Unauthorized" } }
    assert_response :not_found
    post trip_rounds_path(@trip), params: { round: { course: "Unauthorized", plays_on: @trip.starts_on } }
    assert_response :not_found
    post trip_invitations_path(@trip)
    assert_response :not_found
    delete trip_membership_path(@trip, @trip.ownership)
    assert_response :not_found
    post trip_claim_path(@trip)
    assert_response :not_found
  end

  test "scorers can submit a hole but cannot alter its course card or pairings" do
    @trip.memberships.create!(user: @buddy)
    holes_round = @trip.rounds.create!(course: "Holes", plays_on: @trip.starts_on, scoring_mode: :hole_by_hole)
    holes_round.update!(course_confirmed: true)
    sign_in(@buddy)
    get trip_round_path(@trip, holes_round)
    assert_response :success
    assert_not_includes response.body, "Pair a singles match"
    hole = holes_round.holes.first
    patch trip_round_hole_hole_scores_path(@trip, holes_round, hole), params: { strokes: { @player.id.to_s => 4 } }
    assert_equal 4, hole.hole_scores.first.strokes
    patch trip_round_course_card_path(@trip, holes_round), params: { holes: {} }
    assert_response :not_found
    post trip_round_matches_path(@trip, holes_round), params: { match: { home_player_id: @player.id, away_player_id: @player.id } }
    assert_response :not_found
    get edit_trip_round_course_card_path(@trip, holes_round)
    assert_response :success
    assert_not_includes response.body, 'value="Confirm course card"'
  end

  test "revocation blocks future joins but does not revoke current members" do
    @trip.memberships.create!(user: @buddy)
    invitation = @trip.invitations.create!(expires_at: 1.day.from_now)
    token = invitation.join_token
    sign_in(@owner)
    delete trip_invitation_path(@trip, invitation)
    assert invitation.reload.revoked_at
    get join_path(token)
    assert_response :not_found
    assert @trip.memberships.exists?(user: @buddy)
    get trip_path(@trip)
    assert_response :success
  end

  test "removed members lose access on their next request" do
    membership = @trip.memberships.create!(user: @buddy)
    buddy_session = open_session
    buddy_session.post session_path, params: { email_address: @buddy.email_address, password: "test-password-long" }
    sign_in(@owner)
    delete trip_membership_path(@trip, membership)
    assert_not @trip.memberships.exists?(user: @buddy)
    buddy_session.get trip_path(@trip)
    buddy_session.assert_response :not_found
    delete trip_membership_path(@trip, @trip.ownership)
    assert_response :not_found
    assert @trip.reload.ownership
  end

  test "legacy organizers only see unclaimed trips and can claim after signup" do
    legacy = Trip.create!(name: "Existing Trip", destination: "NC", starts_on: "2027-05-01", ends_on: "2027-05-03")
    post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    get trips_path
    assert_includes response.body, "Existing Trip"
    assert_not_includes response.body, "Private Cup"
    get trip_path(@trip)
    assert_response :not_found
    post registration_path, params: { user: { name: "Original Organizer", email_address: "original@example.test", password: "new-password-long", password_confirmation: "new-password-long" } }
    assert_response :created
    post trip_claim_path(legacy)
    assert_redirected_to trip_path(legacy)
    assert_equal "original@example.test", legacy.reload.ownership.user.email_address
    another_legacy = open_session
    another_legacy.post session_path, params: { password: ENV["ORGANIZER_PASSWORD"] }
    another_legacy.get trip_path(legacy)
    another_legacy.assert_response :not_found
  end

  test "login expires and logout revokes the database login" do
    sign_in(@owner)
    login = @owner.logins.last
    delete session_path
    assert_not Login.exists?(login.id)
    get trip_path(@trip)
    assert_redirected_to new_session_path
    sign_in(@owner)
    @owner.logins.last.update!(expires_at: 1.minute.ago)
    get trip_path(@trip)
    assert_redirected_to new_session_path
  end

  test "recovery rotates its code and invalidates every old login" do
    original_code = @buddy.recovery_code
    other_session = open_session
    other_session.post session_path, params: { email_address: @buddy.email_address, password: "test-password-long" }
    old_login = @buddy.logins.last
    post recovery_path, params: { email_address: @buddy.email_address, recovery_code: original_code, password: "replacement-password", password_confirmation: "replacement-password" }
    assert_response :success
    assert_select "#recovery-code[value]"
    assert_not Login.exists?(old_login.id)
    assert @buddy.reload.authenticate("replacement-password")
    assert_not @buddy.valid_recovery_code?(original_code)
    other_session.get trips_path
    other_session.assert_redirected_to new_session_path
    post recovery_path, params: { email_address: @buddy.email_address, recovery_code: original_code, password: "another-password", password_confirmation: "another-password" }
    assert_response :unprocessable_entity
  end

  test "replacing a lost recovery code requires the current password" do
    code = @buddy.recovery_code
    sign_in(@buddy)
    get account_path
    assert_response :success
    post recovery_code_path, params: { password: "wrong" }
    assert_redirected_to account_path
    assert @buddy.reload.valid_recovery_code?(code)
    post recovery_code_path, params: { password: "test-password-long" }
    assert_response :created
    assert_not @buddy.reload.valid_recovery_code?(code)
    assert_select "#recovery-code[value]"
  end

  test "pending invitation survives account creation and requires explicit join" do
    invitation = @trip.invitations.create!(expires_at: 1.day.from_now)
    token = invitation.join_token
    get join_path(token)
    assert_response :success
    post registration_path, params: { user: { name: "New Buddy", email_address: "newbuddy@example.test", password: "new-password-long", password_confirmation: "new-password-long" } }
    assert_response :created
    user = User.find_by!(email_address: "newbuddy@example.test")
    assert_not @trip.memberships.exists?(user: user)
    assert_includes response.body, "Continue to the invitation"
    post join_path(token)
    assert @trip.memberships.exists?(user: user, role: :scorer)
  end
end

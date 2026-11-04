require "test_helper"

class AccountTest < ActiveSupport::TestCase
  def attributes
    { name: "Joe", email_address: "  JOE@EXAMPLE.TEST ", password: "long-test-password", password_confirmation: "long-test-password" }
  end

  test "passwords and recovery codes are stored only as hashes" do
    user = User.create!(attributes)
    assert_equal "joe@example.test", user.email_address
    assert user.authenticate("long-test-password")
    assert_not user.authenticate("wrong")
    assert user.valid_recovery_code?(user.recovery_code)
    assert_not_equal user.recovery_code, user.recovery_code_digest
    assert_not User.column_names.include?("recovery_code")
    assert_not User.new(attributes).valid?
  end

  test "short or unconfirmed passwords are rejected" do
    assert_not User.new(attributes.merge(password: "short", password_confirmation: "short")).valid?
    assert_not User.new(attributes.except(:password_confirmation)).valid?
    assert_not User.new(attributes.merge(password_confirmation: "different")).valid?
  end

  test "signed invitations expire and revoked links remain invalid" do
    trip = build_trip
    invitation = trip.invitations.create!(expires_at: 1.hour.from_now)
    token = invitation.join_token
    assert_equal invitation, Invitation.find_signed(token, purpose: :trip_invite)
    travel 2.hours do
      assert_nil Invitation.find_signed(token, purpose: :trip_invite)
    end
    invitation.update!(revoked_at: Time.current)
    assert_not invitation.active?
    assert_not Invitation.active.exists?(id: invitation.id)
  end
end

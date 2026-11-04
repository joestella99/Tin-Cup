class Invitation < ApplicationRecord
  belongs_to :trip
  validates :expires_at, presence: true
  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def active?
    revoked_at.nil? && expires_at > Time.current
  end

  def join_token
    signed_id(purpose: :trip_invite, expires_at: expires_at)
  end
end

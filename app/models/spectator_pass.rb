# A read-only, explicitly enabled share link. Revoking makes signed URLs unusable.
class SpectatorPass < ApplicationRecord
  belongs_to :trip
  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def share_token
    signed_id(purpose: :trip_spectator)
  end
end

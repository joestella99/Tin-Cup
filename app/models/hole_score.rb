class HoleScore < ApplicationRecord
  belongs_to :hole
  belongs_to :player
  validates :strokes, numericality: { only_integer: true, in: 1..30 }
  validates :player_id, uniqueness: { scope: :hole_id }
  validate :valid_competition

  private

  def valid_competition
    return unless hole && player
    errors.add(:player, "must belong to this trip") if player.trip_id != hole.round.trip_id
    errors.add(:hole, "requires confirmed hole-by-hole scoring") unless hole.round.hole_by_hole? && hole.round.course_confirmed?
  end
end

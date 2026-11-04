class Score < ApplicationRecord
  belongs_to :round
  belongs_to :player
  validates :gross, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 300 }
  validates :player_id, uniqueness: { scope: :round_id }
  validate :same_trip
  validate { errors.add(:round, "uses hole-by-hole scoring") if round&.hole_by_hole? }

  def net
    gross - player.playing_handicap
  end

  private

  def same_trip
    errors.add(:player, "must belong to this trip") if player && round && player.trip_id != round.trip_id
  end
end

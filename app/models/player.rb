class Player < ApplicationRecord
  belongs_to :trip
  belongs_to :team, optional: true
  has_many :hole_scores, dependent: :destroy
  has_many :home_matches, class_name: "Match", foreign_key: :home_player_id, dependent: :destroy
  has_many :away_matches, class_name: "Match", foreign_key: :away_player_id, dependent: :destroy
  validate :team_in_trip
  validate :team_locked_after_pairing, on: :update
  has_many :scores, dependent: :destroy
  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, uniqueness: { scope: :trip_id }
  validates :playing_handicap, numericality: { only_integer: true, in: -10..54 }
  validate :handicap_locked_after_scoring, on: :update

  private

  def team_in_trip
    errors.add(:team, "must belong to this trip") if team && team.trip_id != trip_id
  end

  def team_locked_after_pairing
    if will_save_change_to_team_id? && (home_matches.exists? || away_matches.exists?)
      errors.add(:team, "cannot change while the player is paired in a match")
    end
  end

  def handicap_locked_after_scoring
    if will_save_change_to_playing_handicap? && (scores.exists? || hole_scores.exists? || home_matches.exists? || away_matches.exists?)
      errors.add(:playing_handicap, "cannot change after scores are recorded")
    end
  end
end

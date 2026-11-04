class Player < ApplicationRecord
  belongs_to :trip
  has_many :scores, dependent: :destroy
  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, uniqueness: { scope: :trip_id }
  validates :playing_handicap, numericality: { only_integer: true, in: -10..54 }
  validate :handicap_locked_after_scoring, on: :update

  private

  def handicap_locked_after_scoring
    if will_save_change_to_playing_handicap? && scores.exists?
      errors.add(:playing_handicap, "cannot change after scores are recorded")
    end
  end
end

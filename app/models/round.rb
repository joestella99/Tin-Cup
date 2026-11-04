class Round < ApplicationRecord
  belongs_to :trip
  has_many :scores, dependent: :destroy
  validates :course, :plays_on, presence: true
  validate :within_trip_dates

  private

  def within_trip_dates
    if plays_on && trip && trip.starts_on && trip.ends_on && !plays_on.between?(trip.starts_on, trip.ends_on)
      errors.add(:plays_on, "must fall within the trip dates")
    end
  end
end

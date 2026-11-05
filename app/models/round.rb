class Round < ApplicationRecord
  belongs_to :trip
  belongs_to :golf_course, optional: true
  has_many :scores, dependent: :destroy
  has_many :holes, dependent: :destroy
  has_many :hole_scores, through: :holes
  has_many :matches, dependent: :destroy
  enum :scoring_mode, { total: "total", hole_by_hole: "hole_by_hole" }, validate: true
  after_create :build_default_holes, if: :hole_by_hole?

  def build_default_holes
    1.upto(18) { |number| holes.create!(number: number, par: 4, stroke_index: number) }
  end
  # An imported card is copied only at round creation, never linked live.
  # A partial/unverified external card requires manual confirmation.
  def copy_library_scorecard!
    return unless hole_by_hole? && golf_course&.complete_scorecard?
    raise ArgumentError, "Cannot replace a played scorecard" if hole_scores.exists? || matches.exists?

    holes.delete_all
    golf_course.scorecard_entries.each { |entry| holes.create!(entry) }
    update!(course_confirmed: true)
  end

  validates :course, :plays_on, presence: true
  validate :within_trip_dates

  private

  def within_trip_dates
    if plays_on && trip && trip.starts_on && trip.ends_on && !plays_on.between?(trip.starts_on, trip.ends_on)
      errors.add(:plays_on, "must fall within the trip dates")
    end
  end
end

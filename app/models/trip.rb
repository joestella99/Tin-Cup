class Trip < ApplicationRecord
  has_many :teams, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :rounds, dependent: :destroy
  validates :name, :destination, :starts_on, :ends_on, presence: true
  validate :chronological_dates

  private

  def chronological_dates
    errors.add(:ends_on, "must be on or after the start") if starts_on && ends_on && ends_on < starts_on
  end
end

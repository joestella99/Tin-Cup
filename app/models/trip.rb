class Trip < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :spectator_passes, dependent: :destroy
  has_one :ownership, -> { where(role: "owner") }, class_name: "Membership"
  scope :unclaimed, -> { where.not(id: Membership.owner.select(:trip_id)) }
  has_many :teams, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :rounds, dependent: :destroy
  validates :name, :destination, :starts_on, :ends_on, presence: true
  validate :chronological_dates

  validate :rounds_fit_updated_dates, on: :update

  private

  def rounds_fit_updated_dates
    return unless starts_on && ends_on && ends_on >= starts_on
    return unless will_save_change_to_starts_on? || will_save_change_to_ends_on?

    if rounds.where.not(plays_on: starts_on..ends_on).exists?
      errors.add(:base, "Trip dates must include every scheduled round. Move any affected rounds first.")
    end
  end

  def chronological_dates
    errors.add(:ends_on, "must be on or after the start") if starts_on && ends_on && ends_on < starts_on
  end
end

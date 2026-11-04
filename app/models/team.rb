class Team < ApplicationRecord
  belongs_to :trip
  has_many :players, dependent: :nullify
  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, uniqueness: { scope: :trip_id }
end

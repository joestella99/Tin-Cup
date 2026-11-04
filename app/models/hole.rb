class Hole < ApplicationRecord
  belongs_to :round
  has_many :hole_scores, dependent: :destroy
  validates :number, :stroke_index, numericality: { only_integer: true, in: 1..18 }, uniqueness: { scope: :round_id }
  validates :par, numericality: { only_integer: true, in: 3..6 }
end

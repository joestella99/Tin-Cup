class Membership < ApplicationRecord
  belongs_to :trip
  belongs_to :user
  enum :role, { owner: "owner", scorer: "scorer" }, validate: true
  validates :user_id, uniqueness: { scope: :trip_id }
end

class Login < ApplicationRecord
  belongs_to :user
  validates :expires_at, presence: true
  scope :active, -> { where("expires_at > ?", Time.current) }
end

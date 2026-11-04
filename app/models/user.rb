class User < ApplicationRecord
  has_secure_password reset_token: false
  has_many :logins, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :trips, through: :memberships
  normalizes :email_address, with: ->(email) { email.strip.downcase }
  normalizes :name, with: ->(name) { name.strip }
  validates :email_address, presence: true, uniqueness: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 60 }
  validates :password, length: { minimum: 12 }, if: -> { new_record? || password.present? }
  validates :password_confirmation, presence: true, if: -> { new_record? || password.present? }
  before_create :issue_recovery_code
  attr_reader :recovery_code

  def issue_recovery_code
    @recovery_code = SecureRandom.urlsafe_base64(32)
    self.recovery_code_digest = Digest::SHA256.hexdigest(@recovery_code)
  end

  def valid_recovery_code?(code)
    ActiveSupport::SecurityUtils.secure_compare(recovery_code_digest, Digest::SHA256.hexdigest(code.to_s.strip))
  end
end

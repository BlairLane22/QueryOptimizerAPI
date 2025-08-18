class AppProfile < ApplicationRecord
  has_many :query_analyses, dependent: :destroy
  has_many :optimization_suggestions, through: :query_analyses

  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :api_key_digest, presence: true, uniqueness: true

  def self.authenticate_with_api_key(api_key)
    find_by(api_key_digest: BCrypt::Password.create(api_key))
  end

  def generate_api_key!
    api_key = SecureRandom.hex(32)
    self.api_key_digest = BCrypt::Password.create(api_key)
    save!
    api_key
  end
end

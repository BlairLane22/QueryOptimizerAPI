FactoryBot.define do
  factory :app_profile do
    name { Faker::App.name }
    api_key_digest { BCrypt::Password.create(SecureRandom.hex(32)) }
  end
end

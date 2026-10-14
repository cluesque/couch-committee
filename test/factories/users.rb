FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:display_name) { |n| "User #{n}" }
    sequence(:google_id) { |n| "google-uid-#{n}" }

    trait :invited do
      display_name { nil }
      google_id { nil }
    end
  end
end

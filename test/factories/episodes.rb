FactoryBot.define do
  factory :episode do
    title { association :season, episode_count: 0 }
    sequence(:number)
    sequence(:name) { |n| "Episode #{n}" }
    available_on { Date.new(2026, 1, 1) }
  end
end

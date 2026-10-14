FactoryBot.define do
  factory :play_list do
    group
    sequence(:name) { |n| "Playlist #{n}" }
    description { "Things we want to watch." }
  end
end

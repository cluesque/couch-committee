FactoryBot.define do
  factory :list do
    group
    sequence(:name) { |n| "List #{n}" }
    description { "Things we want to watch." }
  end
end

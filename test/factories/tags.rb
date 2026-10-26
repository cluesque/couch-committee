FactoryBot.define do
  factory :tag do
    list
    sequence(:name) { |n| "Tag #{n}" }
    color { "blue" }
  end
end

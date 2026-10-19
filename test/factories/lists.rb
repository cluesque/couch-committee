FactoryBot.define do
  factory :list do
    sequence(:name) { |n| "List #{n}" }
    description { "Things we want to watch." }

    transient do
      members { [] }
    end

    after(:create) do |list, context|
      context.members.each { |user| create(:list_membership, list: list, user: user) }
    end
  end
end

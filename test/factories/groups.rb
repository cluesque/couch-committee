FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Household #{n}" }

    transient do
      members { [] }
    end

    after(:create) do |group, context|
      context.members.each { |user| create(:group_membership, group: group, user: user) }
    end
  end
end

FactoryBot.define do
  factory :list_entry do
    play_list
    title factory: :movie
    sequence(:sequence)

    trait :cancelled do
      state { :cancelled }
      cancelled_at { Time.current }
      cancel_note { "Not for us." }
    end
  end
end

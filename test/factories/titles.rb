FactoryBot.define do
  factory :title, aliases: [ :movie ] do
    kind { :movie }
    sequence(:name) { |n| "Movie #{n}" }
    episodes { [ association(:episode, title: instance, number: 1, name: name) ] }
  end

  factory :season, class: "Title" do
    kind { :series }
    sequence(:name) { |n| "Series #{n}" }
    season { 1 }

    transient do
      episode_count { 3 }
    end

    episodes { Array.new(episode_count) { |i| association(:episode, title: instance, number: i + 1) } }
  end
end

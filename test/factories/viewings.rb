FactoryBot.define do
  factory :viewing do
    list_entry
    episode { list_entry.title.episodes.first }
    group { list_entry.list.group }
    date { Date.new(2026, 10, 14) }
  end
end

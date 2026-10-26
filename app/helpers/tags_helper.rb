module TagsHelper
  # A list's tag as a soft pill in its color. (Not named `tag`, which would hide Rails' tag builder.)
  def tag_pill(list_tag, **options)
    content_tag :span, list_tag.name, **options, class: [ "tag", "tag-#{list_tag.color}", options[:class] ]
  end

  # Radio buttons for picking a tag's color, each drawn as a pill in that color.
  def tag_color_choices(field_name, selected:, id_prefix:)
    safe_join(Tag::COLORS.map do |color|
      id = "#{id_prefix}_#{color}"
      safe_join([
        radio_button_tag(field_name, color, color == selected, id: id, class: "btn-check"),
        label_tag(id, color.humanize, class: "tag tag-#{color} tag-color-choice")
      ])
    end)
  end
end

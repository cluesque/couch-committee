module ApplicationHelper
  # The "← Parent" link at the top of every page below the home page.
  def back_link(label, path)
    tag.p(link_to("← #{label}", path), class: "small mb-1")
  end
end

require "application_system_test_case"

class ReorderingTest < ApplicationSystemTestCase
  test "dragging an entry to a new place, and it stays there" do
    pat = create(:user)
    @list = create(:list, members: [ pat ], name: "Movie night")
    %w[ First Second Third ].each { |name| @list.add(create(:movie, name: name)) }
    sign_in_as pat

    visit list_path(@list)
    drag "Third", before: "First"

    assert_equal %w[ Third First Second ], entry_names
    assert eventually { saved_order == %w[ Third First Second ] }, "expected the new order to be saved"

    visit current_path
    assert_equal %w[ Third First Second ], entry_names
  end

  private
    # Capybara's drag_to releases straight after its last move, before SortableJS (which samples the
    # pointer every 50ms) has caught up, so drop positions come out nondeterministic.
    def drag(name, before:)
      from = center_of(find("li", text: name).find("[data-sortable-handle]"))
      target = find("li", text: before).evaluate_script("this.getBoundingClientRect().toJSON()")
      mouse = page.driver.browser.mouse

      mouse.move(x: from[:x], y: from[:y])
      mouse.down
      sleep 0.1
      mouse.move(x: from[:x], y: target["top"] + target["height"] / 4, steps: 10)
      sleep 0.2
      mouse.up
    end

    def center_of(element)
      rect = element.evaluate_script("this.getBoundingClientRect().toJSON()")
      { x: rect["left"] + rect["width"] / 2, y: rect["top"] + rect["height"] / 2 }
    end

    def entry_names
      all("ol > li .fw-medium").map(&:text)
    end

    def saved_order
      @list.list_entries.active.order(:sequence).map { |entry| entry.title.name }
    end

    # The save is a fetch that finishes after the drop.
    def eventually(timeout: Capybara.default_max_wait_time)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      until (result = yield) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.05
      end
      result
    end
end

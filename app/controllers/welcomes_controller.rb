# The one-time introduction, shown on the way to Home until it's been seen. "How it works" in the
# account menu reopens it.
class WelcomesController < ApplicationController
  def show
  end

  def update
    Current.user.update!(welcomed_at: Time.current) unless Current.user.welcomed_at
    just_me = Current.user.lists.find_by(name: List::JUST_ME)
    redirect_to just_me || root_path
  end
end

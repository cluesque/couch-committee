# Sends people back to the page they came from, passed along as `return_to`. Only paths within
# this app count, so the parameter can't be used to redirect anywhere else.
module ReturnTo
  extend ActiveSupport::Concern

  included do
    helper_method :return_to_path
  end

  private
    def return_to_path
      path = params[:return_to].to_s
      path if path.start_with?("/") && !path.start_with?("//")
    end
end

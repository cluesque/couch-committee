# For controllers nested under /groups/:group_id. Anything outside the signed-in user's own groups
# is a 404, so non-members can't tell whether a group exists.
module SetCurrentGroup
  extend ActiveSupport::Concern

  included do
    before_action :set_current_group
  end

  private
    def set_current_group
      Current.group = Current.user.groups.find(params[:group_id])
    end
end

# Undoes deleting a list, offered right after.
class Lists::RestorationsController < ApplicationController
  def create
    list = Current.user.deleted_lists.find(params[:list_id])
    list.restore
    redirect_to list, notice: "Restored #{list.name}."
  end
end

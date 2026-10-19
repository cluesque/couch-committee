class Lists::MembershipsController < ApplicationController
  before_action :set_list

  def create
    email = params.expect(:email)
    membership = @list.invite(email)
    redirect_to edit_list_path(@list), notice: "Added #{membership.user.email}."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to edit_list_path(@list), alert: "Couldn't add #{email}: #{error.record.errors.full_messages.to_sentence}."
  end

  def destroy
    membership = @list.list_memberships.find(params[:id])

    if @list.list_memberships.one?
      redirect_to edit_list_path(@list), alert: "A list needs at least one member.", status: :see_other
    elsif membership.user == Current.user
      membership.destroy!
      redirect_to root_path, notice: "You left #{@list.name}.", status: :see_other
    else
      membership.destroy!
      redirect_to edit_list_path(@list), notice: "Removed #{membership.user.name} from #{@list.name}.", status: :see_other
    end
  end

  private
    def set_list
      @list = Current.user.lists.find(params[:list_id])
    end
end

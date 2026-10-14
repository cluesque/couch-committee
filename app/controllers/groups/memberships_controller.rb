class Groups::MembershipsController < ApplicationController
  include SetCurrentGroup

  def create
    email = params.expect(:email)
    membership = Current.group.invite(email)
    redirect_to Current.group, notice: "Added #{membership.user.email}."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to Current.group, alert: "Couldn't add #{email}: #{error.record.errors.full_messages.to_sentence}."
  end

  def destroy
    membership = Current.group.group_memberships.find(params[:id])

    if Current.group.group_memberships.one?
      redirect_to Current.group, alert: "A group needs at least one member.", status: :see_other
    elsif membership.user == Current.user
      membership.destroy!
      redirect_to groups_path, notice: "You left #{Current.group.name}.", status: :see_other
    else
      membership.destroy!
      redirect_to Current.group, notice: "Removed #{membership.user.name}.", status: :see_other
    end
  end
end

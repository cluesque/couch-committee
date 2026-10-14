class GroupsController < ApplicationController
  def index
    @groups = Current.user.groups.order(:name)
  end

  def show
    @group = Current.user.groups.find(params[:id])
    @memberships = @group.group_memberships.includes(:user).sort_by { |membership| membership.user.name.downcase }
  end

  def new
    @group = Group.new
  end

  def create
    @group = Group.new(group_params)
    @group.group_memberships.build(user: Current.user)

    if @group.save
      redirect_to @group, notice: "Created #{@group.name}."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def group_params
      params.expect(group: [ :name ])
    end
end

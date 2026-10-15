class Groups::ListsController < ApplicationController
  include SetCurrentGroup

  before_action :set_list, only: %i[ show edit update ]

  def show
    @entries = @list.list_entries.active.includes(:viewings, title: :episodes).order(:sequence)
  end

  def new
    @list = Current.group.lists.new
  end

  def create
    @list = Current.group.lists.new(list_params)

    if @list.save
      redirect_to [ Current.group, @list ], notice: "Created #{@list.name}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @list.update(list_params)
      redirect_to [ Current.group, @list ], notice: "Saved #{@list.name}."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_list
      @list = Current.group.lists.find(params[:id])
    end

    def list_params
      params.expect(list: [ :name, :description ])
    end
end

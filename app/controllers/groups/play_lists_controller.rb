class Groups::PlayListsController < ApplicationController
  include SetCurrentGroup

  before_action :set_play_list, only: %i[ show edit update ]

  def show
  end

  def new
    @play_list = Current.group.play_lists.new
  end

  def create
    @play_list = Current.group.play_lists.new(play_list_params)

    if @play_list.save
      redirect_to [ Current.group, @play_list ], notice: "Created #{@play_list.name}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @play_list.update(play_list_params)
      redirect_to [ Current.group, @play_list ], notice: "Saved #{@play_list.name}."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_play_list
      @play_list = Current.group.play_lists.find(params[:id])
    end

    def play_list_params
      params.expect(play_list: [ :name, :description ])
    end
end

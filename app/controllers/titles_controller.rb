class TitlesController < ApplicationController
  def index
    @titles = Title.order(:name, :season)
  end

  def show
    @title = Title.find(params[:id])
  end
end

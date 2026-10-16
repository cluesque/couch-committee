class Titles::RefreshesController < ApplicationController
  include ReturnTo

  def create
    title = Title.where.not(tmdb_id: nil).find(params[:title_id])
    Tmdb::Importer.new.refresh(title)
    redirect_to return_to_path || title, notice: "Refreshed #{title.full_name} from TMDB."
  rescue Tmdb::Error
    redirect_to return_to_path || title, alert: "Couldn't reach TMDB just now. Please try again."
  end
end

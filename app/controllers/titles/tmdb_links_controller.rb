# Links a title entered by hand to its TMDB match, filling in its metadata while keeping its
# episodes, and so its watch history.
class Titles::TmdbLinksController < ApplicationController
  include ReturnTo

  before_action :set_title

  def new
    @query = params[:q].presence || @title.name
    kind = @title.series? ? "series" : "movie"
    @results = Tmdb::Client.new.search(@query).select { |result| result.kind == kind }
  rescue Tmdb::Error
    @results = []
    flash.now[:alert] = "Couldn't reach TMDB just now. Please try again."
  end

  def create
    tmdb_id = params.expect(:tmdb_id)

    if (existing = Title.where.not(id: @title.id).find_by(kind: @title.kind, tmdb_id: tmdb_id, season: @title.season))
      redirect_to new_title_tmdb_link_path(@title, return_to: return_to_path),
        alert: "That's already in the catalog as #{existing.full_name}, so linking would duplicate it."
    else
      importer = Tmdb::Importer.new
      @title.series? ? importer.import_season(tmdb_id, @title.season, into: @title) : importer.import_movie(tmdb_id, into: @title)
      redirect_to return_to_path || @title, notice: "Linked #{@title.full_name} to TMDB."
    end
  rescue Tmdb::Error
    redirect_to new_title_tmdb_link_path(@title, return_to: return_to_path),
      alert: "Couldn't get that from TMDB. #{"It may not have Season #{@title.season} of that show. " if @title.series?}Please try again."
  end

  private
    def set_title
      @title = Title.where(tmdb_id: nil).find(params[:title_id])
    end
end

# Where to watch a title, loaded into its page by a lazy Turbo Frame so a slow TMDB call never holds
# up the page itself.
class Titles::WatchProvidersController < ApplicationController
  def show
    @title = Title.where.not(tmdb_id: nil).find(params[:title_id])
    @providers = Tmdb::WatchProviders.for(@title)
  end
end

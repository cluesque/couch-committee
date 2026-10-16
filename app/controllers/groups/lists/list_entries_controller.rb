class Groups::Lists::ListEntriesController < ApplicationController
  include SetCurrentGroup

  TMDB_UNAVAILABLE = "Couldn't reach TMDB just now. Please try again."
  PREVIEW_PARAMS = %i[ tmdb_movie_id tmdb_show_id season q recommendation from ].freeze

  before_action :set_list

  def show
    @entry = @list.list_entries.includes(:viewings, title: :episodes).find(params[:id])
    @active_entry = @list.list_entries.active.find_by(title_id: @entry.title_id) unless @entry.active?
  end

  # Searches TMDB, plus any titles entered by hand before TMDB, until they're linked to it.
  def new
    @query = params[:q].to_s.strip
    @active_title_ids = @list.list_entries.active.pluck(:title_id)
    return if @query.blank?

    @hand_entered_titles = Title.where(tmdb_id: nil).search(@query).limit(10)
    @results = tmdb.search(@query).first(20)
    movie_ids = @results.select { |result| result.kind == "movie" }.map(&:tmdb_id)
    @movies_in_catalog = Title.movie.where(tmdb_id: movie_ids).index_by(&:tmdb_id)
    @only_seasons = only_seasons(@results.select { |result| result.kind == "series" })
    @seasons_in_catalog = Title.series.where(tmdb_id: @only_seasons.keys).index_by { |title| [ title.tmdb_id, title.season ] }
  rescue Tmdb::Error
    @results = []
    @tmdb_unavailable = true
    flash.now[:alert] = TMDB_UNAVAILABLE
  end

  # A TV show's seasons, to pick one to add. The search page's "Seasons ›" buttons POST here (so a
  # recommendation typed there comes along) and are redirected to the GET.
  def seasons
    if request.post?
      return redirect_to seasons_group_list_list_entries_path(Current.group, @list,
        tmdb_show_id: params.expect(:tmdb_show_id), q: params[:q], recommendation: params[:recommendation].presence)
    end

    @query = params[:q]
    @show = show_details(params.expect(:tmdb_show_id))
    @seasons = @show["seasons"].reject { |season| season["season_number"].to_i.zero? }
    @seasons_in_catalog = Title.series.where(tmdb_id: @show["id"]).index_by(&:season)
    @active_title_ids = @list.list_entries.active.pluck(:title_id)
  rescue Tmdb::Error
    redirect_to new_group_list_list_entry_path(Current.group, @list, q: @query), alert: TMDB_UNAVAILABLE
  end

  # A TMDB movie or season, shown as its list entry would be, to look over before adding. Search
  # and season-page buttons POST here (bringing any recommendation typed there) and are redirected.
  def preview
    if request.post?
      return redirect_to preview_group_list_list_entries_path(Current.group, @list,
        **params.slice(*PREVIEW_PARAMS).permit!.to_h.compact_blank.symbolize_keys)
    end

    @query = params[:q]
    @title = if params[:tmdb_movie_id].present?
      importer.build_movie(params[:tmdb_movie_id])
    else
      importer.build_season(params.expect(:tmdb_show_id), params.expect(:season))
    end
    @on_list = @title.persisted? && @list.list_entries.active.exists?(title: @title)
    @providers = Tmdb::WatchProviders.for(@title, client: tmdb)
  rescue Tmdb::Error
    redirect_to search_again_path, alert: TMDB_UNAVAILABLE
  end

  # Adds a TMDB movie, a season of a TMDB show, or a title already in the catalog. TMDB titles are
  # imported (or refreshed, if they're already in the catalog) on the way.
  def create
    title = title_to_add
    entry = @list.add(title, recommendation: params[:recommendation])

    if entry.persisted?
      again = " again" if @list.list_entries.where(title: title).where.not(id: entry.id).exists?
      redirect_to [ Current.group, @list ], notice: "Added #{title.full_name}#{again}."
    else
      redirect_to search_again_path, alert: refusal(title, entry)
    end
  rescue Tmdb::Error, ActiveRecord::RecordInvalid
    redirect_to search_again_path, alert: TMDB_UNAVAILABLE
  end

  def reorder
    @list.reorder(params.expect(list_entry_ids: []))
    head :no_content
  end

  private
    def set_list
      @list = Current.group.lists.find(params[:list_id])
    end

    def title_to_add
      if params[:tmdb_movie_id].present?
        importer.import_movie(params[:tmdb_movie_id])
      elsif params[:tmdb_show_id].present?
        importer.import_season(params[:tmdb_show_id], params.expect(:season))
      else
        Title.find(params.expect(:title_id))
      end
    end

    def tmdb
      @tmdb ||= Tmdb::Client.new
    end

    # Search results don't say how many seasons a show has, so this asks TMDB about each show,
    # briefly cached. A show TMDB can't tell us about just keeps its "Seasons ›" button.
    def show_details(tmdb_show_id)
      Rails.cache.fetch([ "tmdb-tv", tmdb_show_id.to_i ], expires_in: 1.hour) { tmdb.tv(tmdb_show_id) }
    end

    # For shows with exactly one season (not counting TMDB's "Season 0" specials), that season's
    # number, by show ID. Those can be added straight from the results, without the season picker.
    # The lookups run concurrently: one at a time, a search full of shows took seconds.
    def only_seasons(shows)
      lookups = shows.map do |show|
        Thread.new do
          numbers = show_details(show.tmdb_id)["seasons"].map { |season| season["season_number"].to_i }.reject(&:zero?)
          [ show.tmdb_id, numbers.first ] if numbers.one?
        rescue Tmdb::Error
          nil
        end
      end

      ActiveSupport::Dependencies.interlock.permit_concurrent_loads { lookups.filter_map(&:value) }.to_h
    end

    # Back to the search, keeping what was typed.
    def search_again_path
      new_group_list_list_entry_path(Current.group, @list, q: params[:q], recommendation: params[:recommendation].presence)
    end

    def refusal(title, entry)
      if entry.errors.include?(:title)
        "#{title.full_name} #{entry.errors[:title].to_sentence}."
      else
        "Couldn't add #{title.full_name}: #{entry.errors.full_messages.to_sentence}."
      end
    end

    def importer
      Tmdb::Importer.new(client: tmdb)
    end
end

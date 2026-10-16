class Groups::Lists::ListEntriesController < ApplicationController
  include SetCurrentGroup

  TMDB_UNAVAILABLE = "Couldn't reach TMDB just now. Please try again."

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
  rescue Tmdb::Error
    @results = []
    @tmdb_unavailable = true
    flash.now[:alert] = TMDB_UNAVAILABLE
  end

  # A TV show's seasons, to pick one to add.
  def seasons
    @query = params[:q]
    @show = tmdb.tv(params.expect(:tmdb_show_id))
    @seasons = @show["seasons"].reject { |season| season["season_number"].to_i.zero? }
    @seasons_in_catalog = Title.series.where(tmdb_id: @show["id"]).index_by(&:season)
    @active_title_ids = @list.list_entries.active.pluck(:title_id)
  rescue Tmdb::Error
    redirect_to new_group_list_list_entry_path(Current.group, @list, q: @query), alert: TMDB_UNAVAILABLE
  end

  # Adds a TMDB movie, a season of a TMDB show, or a title already in the catalog. TMDB titles are
  # imported (or refreshed, if they're already in the catalog) on the way.
  def create
    title = title_to_add
    entry = @list.add(title)

    if entry.persisted?
      again = " again" if @list.list_entries.where(title: title).where.not(id: entry.id).exists?
      redirect_to [ Current.group, @list ], notice: "Added #{title.full_name}#{again}."
    else
      redirect_to new_group_list_list_entry_path(Current.group, @list, q: params[:q]),
        alert: "#{title.full_name} #{entry.errors[:title].to_sentence}."
    end
  rescue Tmdb::Error, ActiveRecord::RecordInvalid
    redirect_to new_group_list_list_entry_path(Current.group, @list, q: params[:q]), alert: TMDB_UNAVAILABLE
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

    def importer
      Tmdb::Importer.new(client: tmdb)
    end
end

class Lists::ListEntries::ViewingsController < ApplicationController
  before_action :set_list_entry

  # @viewing only carries the form's values; WatchRecorder creates the real Viewing. It's built
  # outside @list_entry.viewings so it can't count as already watched.
  def new
    @viewing = Viewing.new(episode: @list_entry.next_episode || @list_entry.title.episodes.first, date: Date.current)
  end

  def create
    @viewing = Viewing.new(viewing_params)
    episode = @list_entry.title.episodes.find(@viewing.episode_id)

    WatchRecorder.call(@list_entry, episode: episode, date: @viewing.date)
    redirect_to @list, notice: watched_notice(episode)
  rescue ActiveRecord::RecordInvalid => error
    @viewing.errors.merge!(error.record.errors)
    render :new, status: :unprocessable_content
  end

  # Unwatches. Offered from History, so the entry may be finished.
  def destroy
    viewing = @list_entry.viewings.find(params[:id])
    WatchRemover.call(viewing)

    redirect_to list_history_path(@list), status: :see_other,
      notice: "Unwatched #{viewing.episode.full_name}."
  rescue WatchRemover::Refused => refusal
    redirect_to list_history_path(@list), status: :see_other, alert: refusal.message
  end

  private
    def set_list_entry
      @list = Current.user.lists.find(params[:list_id])
      entries = action_name == "destroy" ? @list.list_entries : @list.list_entries.active
      @list_entry = entries.includes(:viewings, title: :episodes).find(params[:list_entry_id])
    end

    def viewing_params
      params.expect(viewing: [ :episode_id, :date ])
    end

    def watched_notice(episode)
      title = @list_entry.title
      [ "Watched #{episode.full_name}.", ("Finished #{title.full_name}." if @list_entry.watched? && !title.movie?) ].compact.join(" ")
    end
end

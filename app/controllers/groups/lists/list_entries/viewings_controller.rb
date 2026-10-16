class Groups::Lists::ListEntries::ViewingsController < ApplicationController
  include SetCurrentGroup

  before_action :set_list_entry

  # @viewing only carries the form's values; WatchRecorder creates the real Viewings. It's built
  # outside @list_entry.viewings so it can't count as already watched.
  def new
    @viewing = Viewing.new(episode: @list_entry.next_episode || @list_entry.title.episodes.first, date: Date.current)
  end

  def create
    @viewing = Viewing.new(viewing_params)
    episode = @list_entry.title.episodes.find(@viewing.episode_id)

    entries = WatchRecorder.call(group: Current.group, episode: episode, date: @viewing.date)
    redirect_to [ Current.group, @list ], notice: watched_notice(episode, entries)
  rescue ActiveRecord::RecordInvalid => error
    @viewing.errors.merge!(error.record.errors)
    render :new, status: :unprocessable_content
  end

  # Unwatches: undoes the watch on every list it was recorded on (see WatchRemover). Offered from
  # History, so the entry may be finished.
  def destroy
    viewing = @list_entry.viewings.find(params[:id])
    others = WatchRemover.call(viewing).map { |removed| removed.list_entry.list }.uniq - [ @list ]

    redirect_to group_list_history_path(Current.group, @list), status: :see_other, notice: [
      "Unwatched #{watch_label(viewing.episode)}.",
      ("Also removed from #{others.map(&:name).sort.to_sentence}." if others.any?)
    ].compact.join(" ")
  rescue WatchRemover::Refused => refusal
    redirect_to group_list_history_path(Current.group, @list), status: :see_other, alert: refusal.message
  end

  private
    def set_list_entry
      @list = Current.group.lists.find(params[:list_id])
      entries = action_name == "destroy" ? @list.list_entries : @list.list_entries.active
      @list_entry = entries.includes(:viewings, title: :episodes).find(params[:list_entry_id])
    end

    def watch_label(episode)
      title = @list_entry.title
      title.movie? ? title.full_name : "episode #{episode.number} of #{title.full_name}"
    end

    def viewing_params
      params.expect(viewing: [ :episode_id, :date ])
    end

    def watched_notice(episode, entries)
      title = @list_entry.title
      this_entry = entries.find { |entry| entry == @list_entry }
      others = (entries - [ this_entry ]).map { |entry| entry.list.name }

      [
        title.movie? ? "Watched #{title.full_name}." : "Watched episode #{episode.number} of #{title.full_name}.",
        ("Finished #{title.full_name}." if this_entry&.watched? && !title.movie?),
        ("Also recorded on #{others.sort.to_sentence}." if others.any?)
      ].compact.join(" ")
    end
end

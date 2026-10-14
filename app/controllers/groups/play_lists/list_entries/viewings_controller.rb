class Groups::PlayLists::ListEntries::ViewingsController < ApplicationController
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
    redirect_to [ Current.group, @play_list ], notice: watched_notice(episode, entries)
  rescue ActiveRecord::RecordInvalid => error
    @viewing.errors.merge!(error.record.errors)
    render :new, status: :unprocessable_content
  end

  private
    def set_list_entry
      @play_list = Current.group.play_lists.find(params[:play_list_id])
      @list_entry = @play_list.list_entries.active.includes(:viewings, title: :episodes).find(params[:list_entry_id])
    end

    def viewing_params
      params.expect(viewing: [ :episode_id, :date ])
    end

    def watched_notice(episode, entries)
      title = @list_entry.title
      this_entry = entries.find { |entry| entry == @list_entry }
      others = (entries - [ this_entry ]).map { |entry| entry.play_list.name }

      [
        title.movie? ? "Watched #{title.full_name}." : "Watched episode #{episode.number} of #{title.full_name}.",
        ("Finished #{title.full_name}." if this_entry&.watched? && !title.movie?),
        ("Also recorded on #{others.sort.to_sentence}." if others.any?)
      ].compact.join(" ")
    end
end

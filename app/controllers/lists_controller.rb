class ListsController < ApplicationController
  before_action :set_list, only: %i[ show edit update destroy ]

  KINDS = %w[ movie series ].freeze

  # Home: every list you're on.
  def index
    return redirect_to welcome_path unless Current.user.welcomed_at

    @lists = Current.user.lists.includes(:users).order(:name)
    @lists_with_entries = ListEntry.where(list: @lists).distinct.pluck(:list_id)
  end

  # Optionally just the movies, or just the series (`kind`), or just what has one of the list's tags
  # (`tag`).
  def show
    entries = @list.list_entries.active.includes(:viewings, :tags, title: :episodes).order(:sequence).to_a
    @kind = params[:kind].presence_in(KINDS)
    @tag = @list.tags.find_by(id: params[:tag]) unless @kind
    @counts = entries.map { |entry| entry.title.kind }.tally
    @tag_counts = entries.flat_map { |entry| entry.tags.map(&:id) }.tally
    @total = entries.size
    @entries = if @kind
      entries.select { |entry| entry.title.kind == @kind }
    elsif @tag
      entries.select { |entry| entry.tags.include?(@tag) }
    else
      entries
    end
  end

  def new
    @list = List.new
  end

  # Whoever creates a list starts as its only member.
  def create
    @list = List.new(list_params)
    @list.list_memberships.build(user: Current.user)

    if @list.save
      redirect_to @list, notice: "Created #{@list.name}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @memberships = memberships
  end

  def update
    if @list.update(list_params)
      redirect_to @list, notice: "Saved #{@list.name}."
    else
      @memberships = memberships
      render :edit, status: :unprocessable_content
    end
  end

  # Soft: the list is hidden from everyone on it, with a chance to undo.
  def destroy
    @list.soft_delete
    redirect_to root_path, notice: "Deleted #{@list.name}.", flash: { restorable_list_id: @list.id }, status: :see_other
  end

  private
    def set_list
      @list = Current.user.lists.find(params[:id])
    end

    def memberships
      @list.list_memberships.includes(:user).sort_by { |membership| membership.user.name.downcase }
    end

    def list_params
      params.expect(list: [ :name, :description ])
    end
end

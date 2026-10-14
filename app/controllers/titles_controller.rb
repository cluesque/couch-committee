class TitlesController < ApplicationController
  # Kinds that have an entry form (app/views/titles/_<kind>_fields).
  ENTERABLE_KINDS = %w[ movie ].freeze

  def index
    @titles = Title.order(:name, :season)
  end

  def show
    @title = Title.find(params[:id])
  end

  def new
    @title = Title.new(kind: enterable_kind(params[:kind]))
    @title.episodes.build(number: 1)
  end

  def create
    @title = Title.new(title_params.merge(kind: enterable_kind(params.dig(:title, :kind))))

    if @title.save
      redirect_to @title, notice: "Added #{@title.full_name}."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def enterable_kind(kind)
      kind.presence_in(ENTERABLE_KINDS) || ENTERABLE_KINDS.first
    end

    def title_params
      params.expect(title: [ :name, :season, episodes_attributes: [ [ :number, :name, :available_on ] ] ])
    end
end

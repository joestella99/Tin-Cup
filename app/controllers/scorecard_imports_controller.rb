class ScorecardImportsController < ApplicationController
  before_action :load_round

  def new
    @selected_player = @players.find_by(id: params[:player_id]) if params[:player_id].present?
  end

  def create
    @selected_player = @players.find(params.require(:player_id))
    uploaded = params[:scorecard_file]
    if uploaded.present?
      raise ScorecardImporter::Invalid, "Upload a text or CSV file." unless uploaded.respond_to?(:read)
      raise ScorecardImporter::Invalid, "Only .csv and .txt files are supported." unless %w[.csv .txt].include?(File.extname(uploaded.original_filename.to_s).downcase)
      input = uploaded.read(32_769)
      raise ScorecardImporter::Invalid, "File exceeds 32 KB." if input.bytesize > 32_768
    else
      input = params[:scores_text].presence || params[:import_values]
    end

    @preview = ScorecardImporter.parse(input)
    @import_values = @preview.join(",")
    @previous_scores = @round.hole_scores.where(player: @selected_player).count
    if params[:confirm] != "1"
      render :new, status: :ok
      return
    end

    if @previous_scores.positive? && params[:replace_existing] != "1"
      @error = "There are already #{@previous_scores} holes saved for this player. Approve replacement to continue."
      render :new, status: :unprocessable_entity
      return
    end

    # Atomic one-player replacement: other golfers' cards cannot be changed.
    @round.with_lock do
      @round.holes.order(:number).each_with_index do |hole, index|
        hole.hole_scores.find_or_initialize_by(player: @selected_player).update!(strokes: @preview[index])
      end
    end
    redirect_to trip_round_path(@trip, @round, player_id: @selected_player.id),
      notice: "Imported 18 scores for #{@selected_player.name}. Standings and matches are updated."
  rescue ScorecardImporter::Invalid => error
    @error = error.message
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    @error = error.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def load_round
    @trip = find_trip!
    @round = @trip.rounds.find(params[:round_id])
    raise ActiveRecord::RecordNotFound unless @round.hole_by_hole? && @round.course_confirmed?
    @players = @trip.players.order(:name)
  end
end

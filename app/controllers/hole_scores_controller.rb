class HoleScoresController < ApplicationController
  def update
    trip = find_trip!
    round = trip.rounds.find(params[:round_id])
    hole = round.holes.find(params[:hole_id])
    cart_mode = params[:cart_mode] == "1"
    if cart_mode
      raise ActiveRecord::RecordNotFound unless round.hole_by_hole? && round.course_confirmed?
      cart_player = trip.players.find(params.require(:player_id))
      if params[:save_custom] == "1"
        raise ActionController::BadRequest, "Enter gross strokes first" if params[:custom_strokes].blank?
        submitted = { cart_player.id.to_s => params[:custom_strokes] }
      else
        submitted = params.fetch(:strokes, ActionController::Parameters.new).permit(cart_player.id.to_s).to_h
        raise ActionController::BadRequest, "Choose a hole score" unless submitted.key?(cart_player.id.to_s)
      end
    else
      submitted = params.fetch(:strokes, ActionController::Parameters.new).permit(*trip.players.pluck(:id).map(&:to_s)).to_h
    end
    # Offline clients submit the score they saw before going offline.
    # Reject conflicting newer edits instead of silently overwriting them.
    # A retry for a score already applied is safe and idempotent.
    cart_sync = cart_mode && params[:cart_sync] == "1"
    round.with_lock do
      if cart_sync
        expected_text = params.require(:cart_expected_strokes).to_s
        raise ActionController::BadRequest, "Invalid expected strokes" unless expected_text == "blank" || expected_text.match?(/\A(?:[1-9]|[12][0-9]|30)\z/)
        expected = expected_text == "blank" ? nil : expected_text.to_i
        desired_text = submitted.fetch(cart_player.id.to_s)
        desired = desired_text.blank? ? nil : Integer(desired_text, exception: false)
        raise ActionController::BadRequest, "Invalid strokes" unless desired.nil? || desired.between?(1, 30)
        actual = hole.hole_scores.find_by(player_id: cart_player.id)&.strokes
        if actual != expected && actual != desired
          return render json: { error: "This hole was changed on another device.", hole: hole.number, server_strokes: actual }, status: :conflict
        end
      end
      submitted.each do |player_id, strokes|
        player = trip.players.find(player_id)
        score = hole.hole_scores.find_or_initialize_by(player: player)
        if strokes.blank?
          score.destroy! if score.persisted?
        else
          score.update!(strokes: strokes)
        end
      end
    end
    if cart_mode
      saved = hole.hole_scores.find_by(player_id: cart_player.id)
      if cart_sync
        # Return a real acknowledgement for local-queue reconciliation.
        pairing = round.matches.includes(:home_player, :away_player).detect do |match|
          match.home_player_id == cart_player.id || match.away_player_id == cart_player.id
        end
        match_data = if pairing
          result = MatchResult.for(pairing)
          { status: result.status, leader_name: result.leader&.name,
            margin: result.margin, through: result.through }
        end
        return render json: { hole: hole.number, strokes: saved&.strokes, match: match_data }
      end
      flash[:cart_result] = {
        "round_id" => round.id, "player_id" => cart_player.id,
        "hole" => hole.number, "par" => hole.par,
        "strokes" => saved&.strokes, "cleared" => saved.nil?
      }
      destination = { player_id: cart_player.id }
      destination[:hole] = saved.nil? ? hole.number : hole.number + 1 if saved.nil? || hole.number < 18
      redirect_to cart_trip_round_path(trip, round, **destination), status: :see_other
    else
      destination = params[:next_hole] == "1" && hole.number < 18 ? hole.number + 1 : hole.number
      redirect_to trip_round_path(trip, round, hole: destination, player_id: focus_player_id(trip)), notice: "Hole #{hole.number} saved. Match standings updated."
    end
  rescue ActiveRecord::RecordInvalid => error
    if params[:cart_sync] == "1"
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    elsif params[:cart_mode] == "1"
      redirect_to cart_trip_round_path(trip, round, hole: hole.number, player_id: params[:player_id]),
        alert: error.record.errors.full_messages.to_sentence
    else
      redirect_to trip_round_path(trip, round, hole: hole.number, player_id: focus_player_id(trip)), alert: error.record.errors.full_messages.to_sentence
    end
  end

  private

  def focus_player_id(trip)
    return "all" if params[:player_id] == "all"
    params[:player_id] if params[:player_id].present? && trip.players.exists?(id: params[:player_id])
  end
end

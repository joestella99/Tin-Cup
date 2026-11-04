class CourseCardsController < ApplicationController
  def edit
    @trip = find_trip!
    @round = @trip.rounds.find(params[:round_id])
    @can_manage = organizer_for?(@trip)
    @holes = @round.holes.order(:number)
    redirect_to trip_round_path(@trip, @round), alert: "This round uses total scores." unless @round.hole_by_hole?
  end

  def update
    @trip = find_trip!(manage: true)
    @round = @trip.rounds.find(params[:round_id])
    raise ActiveRecord::RecordNotFound unless @round.hole_by_hole?
    submitted = params.require(:holes)
    @round.with_lock do
      if @round.hole_scores.exists? || @round.matches.exists?
        return redirect_to trip_round_path(@trip, @round), alert: "Course details lock after scoring or pairing begins."
      end
      @holes = @round.holes.order(:number).to_a
      attributes = @holes.to_h do |hole|
        [ hole.id, submitted.require(hole.id.to_s).permit(:par, :stroke_index).to_h ]
      end
      indices = attributes.values.map { |attrs| Integer(attrs.fetch("stroke_index"), exception: false) }
      raise ArgumentError, "Stroke indexes must contain every number from 1 to 18 once." unless indices.sort_by(&:to_i) == (1..18).to_a
      # All writes are within the lock's transaction. Recreate the unplayed card to allow index swaps under unique constraints.
      @round.holes.destroy_all
      @holes.each do |hole|
        @round.holes.create!(number: hole.number, **attributes.fetch(hole.id))
      end
      @round.update!(course_confirmed: true)
    end
    redirect_to trip_round_path(@trip, @round), notice: "Course card confirmed. Ready to score and pair matches."
  rescue ActiveRecord::RecordInvalid, ArgumentError, KeyError => error
    redirect_to edit_trip_round_course_card_path(@trip, @round), alert: error.message
  end
end

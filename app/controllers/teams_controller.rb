class TeamsController < ApplicationController
  def destroy
    trip = find_trip!(manage: true)
    team = trip.teams.find(params[:id])
    name = team.name
    removed_players = 0
    removed_matches = 0
    trip.with_lock do
      player_ids = team.players.pluck(:id)
      removed_players = player_ids.size
      affected_matches = Match.where(home_player_id: player_ids).or(Match.where(away_player_id: player_ids))
      removed_matches = affected_matches.count
      affected_matches.destroy_all
      team.destroy!
    end
    redirect_to trip_path(trip, view: "manage", anchor: "manage-teams"),
      notice: "#{name} removed. #{removed_players} #{'golfer'.pluralize(removed_players)} unassigned and #{removed_matches} #{'pairing'.pluralize(removed_matches)} removed; individual scores are preserved.", status: :see_other
  end

  def create
    trip = find_trip!(manage: true)
    team = trip.teams.build(params.require(:team).permit(:name))
    if team.save
      redirect_to trip, notice: "#{team.name} is in the cup."
    else
      redirect_to trip, alert: team.errors.full_messages.to_sentence
    end
  end
end

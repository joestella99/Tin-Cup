class Match < ApplicationRecord
  belongs_to :round
  belongs_to :home_player, class_name: "Player"
  belongs_to :away_player, class_name: "Player"
  validate :eligible_pairing

  private

  def eligible_pairing
    return unless round && home_player && away_player
    errors.add(:round, "must use confirmed hole-by-hole scoring") unless round.hole_by_hole? && round.course_confirmed?
    players = [ home_player, away_player ]
    errors.add(:base, "Choose two different players from this trip") if home_player == away_player || players.any? { |p| p.trip_id != round.trip_id }
    errors.add(:base, "Players must represent different teams") if players.any? { |p| p.team_id.nil? } || home_player.team_id == away_player.team_id
    other_matches = round.matches.where.not(id: id)
    if other_matches.where(home_player_id: players.map(&:id)).or(other_matches.where(away_player_id: players.map(&:id))).exists?
      errors.add(:base, "A player can only appear in one singles match per round")
    end
  end
end

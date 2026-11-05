# A small, deterministic briefing for the whole trip. No invented scores or AI calls.
# The story changes with the actual match and Cup results.
class TripPulse
  include Rails.application.routes.url_helpers

  Step = Data.define(:title, :detail, :done, :path)
  Story = Data.define(:kicker, :headline, :detail)

  attr_reader :trip, :rounds, :players, :teams

  def initialize(trip, cup_entries: nil)
    @trip = trip
    @rounds = trip.rounds.includes(matches: [ :home_player, :away_player ]).order(:plays_on, :id).to_a
    @players = trip.players.to_a
    @teams = trip.teams.to_a
    @cup_entries = cup_entries || CupStandings.for(trip)
  end

  def steps
    list = [
      Step.new("Bring the players", "Add everyone and their agreed handicap.", players.any?, trip_path(trip, view: "manage", anchor: "add-player")),
      Step.new("Pick the sides", "Create teams and assign every player.", teams.size >= 2 && players.any? && players.all?(&:team_id), trip_path(trip, view: "manage", anchor: "manage-teams")),
      Step.new("Set the itinerary", "Schedule at least one round.", rounds.any?, trip_path(trip, view: "manage", anchor: "schedule-round")),
      Step.new("Prepare the scorecards", "Confirm par and stroke indexes for each hole-by-hole round.", rounds.any? && rounds.all? { |round| round.total? || round.course_confirmed? }, trip_path(trip, view: "play"))
    ]
    if trip.ownership
      list << Step.new("Bring the buddies in", "Share the invitation with at least one player.", trip.memberships.count > 1, trip_path(trip, view: "manage", anchor: "trip-access"))
    end
    list
  end

  def completed_steps
    steps.count(&:done)
  end

  def ready?
    steps.all?(&:done)
  end

  def progress(round)
    return 0 if players.empty?
    count = round.hole_by_hole? ? round.hole_scores.count : round.scores.count
    total = players.size * (round.hole_by_hole? ? 18 : 1)
    [ (100.0 * count / total).round, 100 ].min
  end

  def round_state(round)
    return "Needs course card" if round.hole_by_hole? && !round.course_confirmed?
    percentage = progress(round)
    return "Finished" if percentage == 100
    return "In play" if percentage.positive?
    round.plays_on < Date.current ? "Awaiting scores" : "Ready for tee-off"
  end

  def focus_round
    rounds.find { |round| round.plays_on >= Date.current && progress(round) < 100 } ||
      rounds.find { |round| progress(round) < 100 } || rounds.last
  end

  def story
    live = rounds.flat_map(&:matches).filter_map do |match|
      result = MatchResult.for(match)
      [ match, result ] if result.status == :live
    end.min_by { |_, result| [ result.margin.abs, -result.through ] }

    if live
      match, result = live
      detail = if result.leader
        "#{result.leader.name} is #{result.margin} up through #{result.through}. #{match.home_player.name} vs #{match.away_player.name} is still being decided."
      else
        "#{match.home_player.name} and #{match.away_player.name} are all square through #{result.through}. Every hole matters."
      end
      return Story.new("RIVALRY RADAR · LIVE", "This match is the one to watch.", detail)
    end

    if @cup_entries.size >= 2 && @cup_entries.first.points.positive?
      leader = @cup_entries.first
      runner_up = @cup_entries.second
      if leader.points > runner_up.points
        return Story.new("THE CUP CHASE", "#{leader.team.name} has the clubhouse lead.",
          "#{leader.points.to_i == leader.points ? leader.points.to_i : leader.points} Cup points to #{runner_up.points.to_i == runner_up.points ? runner_up.points.to_i : runner_up.points} for #{runner_up.team.name}. The next match could change everything.")
      end
      return Story.new("THE CUP CHASE", "Nobody has pulled away.",
        "The top teams are tied on #{@cup_entries.first.points} Cup points. The next decisive match breaks the deadlock.")
    end

    if teams.size >= 2
      Story.new("THE STORY BEFORE THE FIRST TEE", "#{teams.first.name} vs #{teams.second.name}.", "The squads are forming. Once the first match goes live, this briefing follows the closest battle automatically.")
    elsif players.any?
      Story.new("THE STORY BEFORE THE FIRST TEE", "The cast is coming together.", "#{players.size} #{'golfer'.pluralize(players.size)} on the roster. Give them a side, schedule the courses, and let the rivalry write itself.")
    else
      Story.new("EVERY GREAT CUP STARTS SOMEWHERE", "The first chapter is yours.", "Bring the group together, name the teams, and build a tournament you'll talk about all year.")
    end
  end
end

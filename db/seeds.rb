if Rails.env.production?
  abort "Demo seeds are disabled in production."
end
Trip.find_or_create_by!(name: "The Sandhills Invitational") do |trip|
  trip.destination = "Pinehurst, North Carolina"
  trip.starts_on = Date.new(2027, 5, 13)
  trip.ends_on = Date.new(2027, 5, 16)
end.tap do |trip|
  players = [ [ "Joe", 12 ], [ "Matt", 8 ], [ "Chris", 18 ], [ "Dan", 15 ] ].map do |name, handicap|
    trip.players.find_or_create_by!(name: name) { |p| p.playing_handicap = handicap }
  end
  [ [ "Pine Needles", 13, [ 87, 83, 94, 90 ] ], [ "Mid Pines", 14, [ 84, 81, 93, 88 ] ], [ "Tobacco Road", 15, nil ] ].each do |course, day, totals|
    round = trip.rounds.find_or_create_by!(course: course) { |r| r.plays_on = Date.new(2027, 5, day) }
    players.each_with_index { |p, i| round.scores.find_or_create_by!(player: p) { |s| s.gross = totals[i] } } if totals
  end
end

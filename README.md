# Tin Cup

**The trip is the tournament.** A Ruby on Rails workspace for a group of buddies' annual golf competition.

## First playable slice

- Password-protected organizer workspace, with session rotation and login rate limiting.
- Create trips, add players with agreed playing handicaps, and schedule rounds within trip dates.
- Enter and correct 18-hole gross totals; all changes in a scorecard save atomically.
- Cumulative net leaderboard with ties and completion-aware placement. Incomplete players display pending and cannot take the lead.
- Responsive clubhouse-inspired interface and repeatable fictional demo data.
- PostgreSQL foreign keys, unique indexes, score constraints, model tests, and request-flow tests.

## Run locally

Install Ruby 3.3.6, PostgreSQL, and Bundler. Start PostgreSQL with a local role that can create databases.

```sh
bundle install
export ORGANIZER_PASSWORD='choose-a-long-unique-password'
bin/rails db:prepare
bin/rails db:seed
bin/rails server
```

Open http://localhost:3000 and sign in with your configured password. `.env.example` documents configuration; it is not automatically loaded. No real player data is included.

Alternatively, with Docker installed:

```sh
export ORGANIZER_PASSWORD='choose-a-long-unique-password'
docker compose up --build
# In another terminal, once the app is running:
docker compose exec web bin/rails db:seed
```

## Tests

```sh
bin/rails db:test:prepare
bin/rails test
```

GitHub Actions runs the suite with PostgreSQL. Ruby, Rails, and gem versions are captured in `.ruby-version`, `Gemfile`, and `Gemfile.lock`.

## Scoring rules in v1

Every round is 18 holes of individual stroke play. Net = gross strokes minus the player's agreed playing handicap for that round. The same allowance applies to every round in this version. A negative allowance represents a plus handicap. This is **not** an official handicap-index-to-course-handicap calculator.

Trip standings use the sum of recorded net totals. Only players with a score for every scheduled round receive a placement; equal totals share a place. Pending players are grouped by rounds completed before net score so fewer rounds never imply a lead. A blank score removes an entry. Handicaps lock once a player has scores, to prevent retroactive changes to results.

## Architecture

Rails MVC + PostgreSQL + Hotwire/importmap. Trip owns players and rounds; a score connects a player to a round, with model validation preventing cross-trip submissions. `Leaderboard` handles aggregation separately from controllers. No external scoring or course API is required.

## Next milestones

1. Hole-by-hole scorecards and per-round tees/course handicaps.
2. Two-team trip cups, singles match play, pairings, and match points.
3. Best ball, scramble, and mixed-format trip totals.
4. Individual accounts, trip-scoped permissions, and invitation links.
5. Live leaderboard broadcasts and past-trip champions.

## Deployment boundary

This initial release is a shared organizer workspace: anyone with the password can manage every trip on that instance. It is not yet a public multi-tenant service. Keep the password private and use HTTPS in production. Production needs `SECRET_KEY_BASE`, `DATABASE_URL`, and `ORGANIZER_PASSWORD`; use Rails' standard production server setup and run `db:prepare` during release. No deployment is provisioned by this repository.

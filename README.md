# Tin Cup

**The trip is the tournament.** A Ruby on Rails workspace for a group of buddies' annual golf competition.

## Accounts, private trips, and invitations

- Create a personal account with a name, email identifier, and a password of at least 12 characters. Passwords use Rails `has_secure_password` with bcrypt.
- New trips belong to the account that creates them. Other accounts cannot list or open them without an invitation.
- Organizers create, replace, or revoke a signed invitation link. Links expire after 14 days. Joining grants scorer access only; it never transfers ownership.
- Scorers can read their trips and enter group scores, while only the owner manages rosters, teams, course cards, pairings, invitations, and membership.
- Revoking an invite prevents future joins. Remove an existing member separately to end their current access; revoke active links too if they should not rejoin.
- Logins expire after 14 days and are tracked in the database. Logout deletes the current login; account recovery invalidates all previous logins.
- Signup displays a high-entropy recovery code once. Only its SHA-256 digest is saved. Recovery consumes the old code and issues a replacement. An authenticated user can replace a lost code from their account page after confirming their current password.
- No email delivery or address verification is configured. Email is a sign-in identifier, and the saved recovery code is the recovery method. Do not imply that a reset email has been sent.
- Existing shared-organizer access remains under **Existing organizer access** on the sign-in page. It can access only trips without an owner. Create/sign in to a personal account from that session, then claim each old trip to enable private invitations. Claimed trips disappear from shared-organizer access.
- All nested resource actions check trip membership and organizer permissions on the server. Private pages use `no-store` and `no-referrer` response headers.

## Trip cup and hole-by-hole scoring

- Create any number of teams with any number of players; no fixed two-team limit.
- Assign players to teams, then pair singles matches between any two different teams.
- New hole-by-hole rounds start with an 18-hole course setup. Confirm the actual par and stroke indexes before scoring; placeholder values are not presented as real course data.
- Enter one hole at a time for the group. Individual totals and match standings recalculate on save.
- Match play uses the difference between players' agreed playing handicaps. Wins earn one cup point, ties earn half a point each; unfinished matches award no points.
- Teams share one points table across all rounds. Equal points are tied. Organizers schedule a balanced number of matches per team; there is no automatic bracket or round-robin generator.
- Match results use consecutive scored holes from hole 1 and finish when a player is mathematically ahead, or after 18 holes. Later corrections recalculate the result.
- Course details lock after scoring or pairing starts. Teams and handicaps lock for paired players. Unplayed pairings can be removed before either player has entered scores.
- Individual trip standings count only completed 18-hole rounds. Existing total-score rounds remain supported.

## Live clubhouse

- Every member of a trip can open the live clubhouse from the trip or round screen.
- The clubhouse shows a selectable round leaderboard with provisional net-to-par performance, scoring progress, the overall team cup table, and singles match status.
- Birdies, eagles, albatrosses, and holes-in-one from all confirmed hole-by-hole rounds populate a recent highlight reel. Corrections replace the earlier result instead of creating duplicate claims.
- Scores are read directly from the current database and the clubhouse frame refreshes every 25 seconds while the page is visible, or instantly via the Refresh control. The clubhouse never leaks private trip data outside membership checks.
- No additional services, database tables, push infrastructure, or secrets are required.

## Foundation

- Personal accounts and a legacy organizer migration path, with session rotation and login rate limiting.
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

Open http://localhost:3000 and create a personal account. For legacy access, expand Existing organizer access and use your configured password. `.env.example` documents configuration; it is not automatically loaded. No real player data is included.

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

Individual standings use 18-hole net stroke play. Rounds can use total-score entry or hole-by-hole entry with optional singles matches. Net = gross strokes minus the player's agreed playing handicap for that round. The same allowance applies to every round in this version. A negative allowance represents a plus handicap. This is **not** an official handicap-index-to-course-handicap calculator.

Trip standings use the sum of recorded net totals. Only players with a score for every scheduled round receive a placement; equal totals share a place. Pending players are grouped by rounds completed before net score so fewer rounds never imply a lead. A blank score removes an entry. Handicaps lock once a player has scores, to prevent retroactive changes to results.

## Architecture

Rails MVC + PostgreSQL + Hotwire/importmap. Trip owns players and rounds; a score connects a player to a round, with model validation preventing cross-trip submissions. `Leaderboard` handles aggregation separately from controllers. No external scoring or course API is required.

## Next milestones

1. Per-round tees and playing-handicap allowances.
2. Best ball, scramble, and mixed-format trip totals.
3. Round-robin pairing suggestions for competitions with several teams.
4. Player-to-account roster links and per-foursome scoring permissions.
5. Leaderboard broadcasts and past-trip champions.

## Deployment boundary

The app supports account-owned private trips. A group invite link grants access to anyone who has the link until it expires or is revoked. Share it only with the intended group. Existing shared-organizer credentials can manage unclaimed legacy trips, but cannot access other accounts' private trips. Recoveries use saved codes; email delivery and email verification are not configured.

Production uses `SECRET_KEY_BASE`, `DATABASE_URL`, and the existing `ORGANIZER_PASSWORD` for legacy access. Keep the Rails secret key stable across deploys because it signs sessions and invitation links. `render.yaml` defines the Rails service and shared PostgreSQL database.

## Deploy on Render

Use the repository's `render.yaml` as a Render Blueprint, or open [Deploy to Render](https://render.com/deploy?repo=https://github.com/joestella99/Tin-Cup). Set a private `ORGANIZER_PASSWORD` in Render when prompted for legacy access. New users sign up with their own credentials. The blueprint generates `SECRET_KEY_BASE` and wires the database URL without committing either secret.

The build installs gems and precompiles production assets. Startup checks required environment variables, prepares the database, and starts Puma on Render's assigned port. Demo seeds are not loaded in production. Create a personal account, save the recovery code, and create your first private trip.

The initial configuration uses **free** plans. Free web instances may sleep between visits, and **Render's free PostgreSQL database expires after 30 days**. Upgrade the database before relying on this instance for ongoing trip records. No paid resources are selected by this blueprint.

The deployment configuration is committed; a live deployment still requires a connected Render account and successful provisioning. Verify `/up`, sign-in, trip creation, and persistence after a restart before sharing it with the group.

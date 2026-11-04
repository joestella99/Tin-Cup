#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL must be configured}"
: "${SECRET_KEY_BASE:?SECRET_KEY_BASE must be configured}"
: "${ORGANIZER_PASSWORD:?Set a private organizer password in Render}"
bin/rails db:prepare
exec bundle exec puma -C config/puma.rb

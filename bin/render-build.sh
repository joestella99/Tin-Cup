#!/usr/bin/env bash
set -euo pipefail
bundle install
SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

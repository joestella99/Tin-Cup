Rails.application.config.session_store :cookie_store,
  key: "_tin_cup_session", expire_after: 14.days, same_site: :lax, secure: Rails.env.production?

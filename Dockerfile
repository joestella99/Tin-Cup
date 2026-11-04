FROM ruby:3.3.6-slim
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential libpq-dev libyaml-dev curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
EXPOSE 3000
CMD ["sh", "-c", "bin/rails db:prepare && bin/rails server -b 0.0.0.0"]

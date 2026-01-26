FROM ruby:3.2-slim

# Install build dependencies for native gem extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Install dependencies (skip development gems like rubocop)
COPY Gemfile Gemfile.lock* ./
RUN bundle config set --local without 'development' && bundle install

# Copy all Ruby files into the container
COPY *.rb .

# Command to run the script
CMD ["ruby", "main.rb"]
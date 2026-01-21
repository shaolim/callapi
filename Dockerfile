FROM ruby:3.2-slim

# Set the working directory
WORKDIR /app

# Install dependencies (skip development gems like rubocop)
COPY Gemfile ./
RUN bundle install --without development

# Copy all Ruby files into the container
COPY *.rb .

# Command to run the script
CMD ["ruby", "main.rb"]
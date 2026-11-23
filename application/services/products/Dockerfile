FROM docker.io/library/ruby:3.3-slim
ENV APP_ENV=production \
    BUNDLE_WITHOUT=development:test
WORKDIR /app
COPY Gemfile ./
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && bundle install \
    && apt-get purge -y build-essential && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
COPY app.rb products.json ./
RUN useradd -r -u 10001 app
USER 10001
EXPOSE 4567
CMD ["ruby", "app.rb"]

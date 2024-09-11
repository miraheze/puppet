FROM ruby:latest
MAINTAINER harbottle
RUN echo -e "gem: --no-rdoc --no-ri" > ~/.gemrc
WORKDIR /root/
COPY Gemfile* /root/
RUN bundle install --system

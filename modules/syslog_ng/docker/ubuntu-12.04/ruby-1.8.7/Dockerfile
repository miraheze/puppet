FROM ubuntu:12.04

MAINTAINER Tibor Benke ihrwein@gmail.com

RUN apt-get update -qq && \
    apt-get install -qq ruby1.8-full rubygems1.8 git
RUN gem install bundler

ADD Gemfile /tmp/
RUN cd /tmp && bundle install

RUN mkdir /src
ADD module.tar.gz /src/
WORKDIR /src

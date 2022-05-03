#!/usr/bin/env ruby
# frozen_string_literal: true
#
# プロコンに接続するコマンド

require 'bundler/inline'
require "bundler/setup"
require "switch_connection_manager"

gemfile do
  source 'https://rubygems.org'
  git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }
  gem 'pry'
end

SwitchConnectionManager::Procon.new.run

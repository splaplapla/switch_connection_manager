#!/usr/bin/env ruby
# frozen_string_literal: true
#
# プロコンに接続するコマンド

require 'bundler/inline'
require "bundler/setup"
require 'pry'
require "switch_connection_manager"

SwitchConnectionManager::Procon.new.run

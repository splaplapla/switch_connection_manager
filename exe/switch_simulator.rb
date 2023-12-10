#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Switchに対してプロコンが接続しているかのように振る舞うコマンド

require "bundler/setup"
require "switch_connection_manager"

SwitchConnectionManager::ProconSimulator.new.run

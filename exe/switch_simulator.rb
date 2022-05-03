#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "switch_connection_manager"

SwitchConnectionManager::SwitchSimulator.new.run

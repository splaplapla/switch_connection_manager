#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "switch_connection_manager"

procon = SwitchConnectionManager::Procon.new
procon.prepare!

SwitchConnectionManager::ProconSimulator2.new(mac_addr: procon.mac_addr).run

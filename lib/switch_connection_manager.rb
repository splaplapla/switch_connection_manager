# frozen_string_literal: true

require 'logger'

module SwitchConnectionManager
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.logger=(logger)
    @logger = logger
  end
end

require 'switch_connection_manager/version'
require 'switch_connection_manager/procon_simulator'
require 'switch_connection_manager/procon_simulator2'
require 'switch_connection_manager/procon'
require 'switch_connection_manager/old_procon'
require 'switch_connection_manager/mouse'
require 'switch_connection_manager/procon/procon_connection_status'
require 'switch_connection_manager/procon/procon_internal_status'
require 'switch_connection_manager/support/mouse_finder'
require 'switch_connection_manager/support/procon_finder'
require 'switch_connection_manager/support/usb_device_controller'

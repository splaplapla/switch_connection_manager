# frozen_string_literal: true

require_relative "switch_connection_manager/version"
require_relative "switch_connection_manager/procon_connection_status"
require_relative "switch_connection_manager/procon_finder"
require_relative "switch_connection_manager/procon_simulator"
require_relative "switch_connection_manager/procon"
require_relative "switch_connection_manager/procon_internal_status"

module SwitchConnectionManager
  class Error < StandardError; end
  # Your code goes here...
end

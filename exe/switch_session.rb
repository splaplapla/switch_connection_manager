#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'switch_connection_manager'

switch_session = SwitchConnectionManager::SwitchSession.new

puts 'starting switch session prepare...'
switch_session.prepare!

puts 'starting switch session read...'
switch_session.send(:start_procon_simulator_thread)

self_read, self_write = IO.pipe
%w[TERM INT QUIT].each do |sig|
  trap sig do
    self_write.puts(sig)
  end
end

sleep 10
Process.kill 'TERM', $$

while (readable_io = IO.select([self_read]))
  signal = readable_io.first[0].gets.strip
  case signal
  when 'TERM', 'INT', 'QUIT'
    procon_session.shutdown
    switch_session.shutdown
    exit
  end
end

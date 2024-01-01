#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'switch_connection_manager'

puts 'starting procon session...'
procon_session = SwitchConnectionManager::ProconSession.new
procon_session.prepare!

puts 'procon testing...'
10.times do
  procon_session.read_once
end
puts 'finished procon testing.'
puts "procon.mac_addr is `#{procon_session.mac_addr}`"

puts 'starting switch session...'
switch_session = SwitchConnectionManager::SwitchSession.new(
  mac_addr: procon_session.mac_addr, procon_file: procon_session.device,
)

puts 'starting switch session prepare...'
switch_session.prepare!

puts 'starting switch session read...'
Thread.new do
  loop do
    switch_session.device.write(procon_session.non_blocking_read_with_timeout)
  end
end


sleep 1
Process.kill 'TERM', $$


self_read, self_write = IO.pipe
%w[TERM INT QUIT].each do |sig|
  trap sig do
    self_write.puts(sig)
  end
end

while (readable_io = IO.select([self_read]))
  signal = readable_io.first[0].gets.strip
  case signal
  when 'TERM', 'INT', 'QUIT'
    procon_session.shutdown
    switch_session.shutdown
    exit
  end
end

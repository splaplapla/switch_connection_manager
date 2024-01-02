#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'switch_connection_manager'

puts 'starting procon session...'
procon_session = SwitchConnectionManager::ProconSession.new
procon_session.prepare!

puts 'procon testing...'
# 10.times do
#   raw_data = procon_session.non_blocking_read_with_timeout
#   data = raw_data.unpack1('H*')
#   puts "procon testing: #{data}"
# end
puts 'finished procon testing.'

puts
puts '-----------------------'
puts
puts "procon.mac_addr is `#{procon_session.mac_addr}`"
puts "procon.connection_id is `#{procon_session.connection_id}`"
puts "procon.battery_level is `#{procon_session.battery_level}`"
puts
puts '-----------------------'
puts

puts 'starting switch session...'
switch_session = SwitchConnectionManager::SwitchSession.new(
  mac_addr: procon_session.mac_addr,
  procon_file: procon_session.device,
  connection_id: procon_session.connection_id,
  battery_level: procon_session.battery_level
)

puts 'starting switch session prepare...'
switch_session.prepare!

puts 'starting switch session read...'
# Switch <<< Procon
Thread.new do
  sleep 1
  count = 0
  GC.disable

  loop do
    count = count + 1
    break if switch_session.terminated?

    # FIXME: 初期だとコントローラーが認識されないので認識されるinputを注入して、認識されたらbypassしたinputを渡す
    real = count > 10 ? true : false

    if real
      raw_data = procon_session.non_blocking_read_with_timeout
      begin
        switch_session.device.write_nonblock(raw_data)
      rescue IO::EAGAINWaitReadable
        print '.'
      end
    else
      switch_session.send(:any_input_response)
    end
  end
end

# Switch >>> void
Thread.new do
  15.times do
    break if switch_session.terminated?

    switch_session.send(:read_once)
  end
end

self_read, self_write = IO.pipe
%w[TERM INT QUIT].each do |sig|
  trap sig do
    self_write.puts(sig)
  end
end

sleep 50
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

#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "switch_connection_manager"

procon = SwitchConnectionManager::ProconSession.new
procon.prepare!

self_read, self_write = IO.pipe
%w[TERM INT QUIT].each do |sig|
  trap sig do
    self_write.puts(sig)
  end
end

switch_session = SwitchConnectionManager::SwitchSession.new(mac_addr: procon.mac_addr, procon_file: procon.device)
switch_session.prepare!

Thread.new do
  switch_session.run
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

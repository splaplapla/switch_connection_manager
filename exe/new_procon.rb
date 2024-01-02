#!/usr/bin/env ruby
# frozen_string_literal: true

#
# プロコンに接続するコマンド

require 'bundler/inline'
require 'bundler/setup'
require 'pry'
require 'switch_connection_manager'

procon_session = SwitchConnectionManager::ProconSession.new
procon_session.prepare!

puts 'procon testing...'
10.times do
  procon_session.read_once
end
puts 'finished procon testing.'
puts "procon.mac_addr is `#{procon_session.mac_addr}`"
puts "procon.connection_id is `#{procon_session.connection_id}`"
puts "procon.battery_level is `#{procon_session.battery_level}`"

self_read, self_write = IO.pipe
%w[TERM INT QUIT].each do |sig|
  trap sig do
    self_write.puts(sig)
  end
end

Thread.new do
  procon_session.blocking_read_and_print # ブロッキングする
end

sleep 1
Process.kill 'TERM', $$

while (readable_io = IO.select([self_read]))
  signal = readable_io.first[0].gets.strip
  case signal
  when 'TERM', 'INT', 'QUIT'
    procon_session.shutdown
    exit
  end
end

# NOTE: ライブラリとして呼び出す時は以下のメソッドを適宜呼び出す
# @example procon#device、 Fileインスタンスを返す
# @example procon#shutdown、終了するためにbluetooth接続に戻す

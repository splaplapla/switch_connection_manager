#!/usr/bin/env ruby
# frozen_string_literal: true

#
# プロコンに接続するコマンド

require 'bundler/inline'
require 'bundler/setup'
require 'pry'
require 'switch_connection_manager'

procon = SwitchConnectionManager::Procon.new
procon.prepare!
puts "procon.mac_addr is `#{procon.mac_addr}`"

self_read, self_write = IO.pipe
%w[TERM INT QUIT].each do |sig|
  trap sig do
    self_write.puts(sig)
  end
end

Thread.new do
  procon.read_and_print # ブロッキングする
end

while (readable_io = IO.select([self_read]))
  signal = readable_io.first[0].gets.strip
  case signal
  when 'TERM', 'INT', 'QUIT'
    procon.shutdown
    exit
  end
end

# NOTE: ライブラリとして呼び出す時は以下のメソッドを適宜呼び出す
# @example procon#device、 Fileインスタンスを返す
# @example procon#shutdown、終了するためにbluetooth接続に戻す

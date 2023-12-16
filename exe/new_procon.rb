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

shutdown_block = lambda {
  procon.shutdown
  exit
}

Signal.trap(:INT, &shutdown_block)
Signal.trap(:TERM, &shutdown_block)

procon.read_and_print # ブロッキングする

# NOTE: ライブラリとして呼び出す時は以下のメソッドを適宜呼び出す
# @example procon#device、 Fileインスタンスを返す
# @example procon#shutdown、終了するためにbluetooth接続に戻す

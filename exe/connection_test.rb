#!/usr/bin/env ruby
#
# プロコンのみの接続テスト用最低限のコマンド
# * Switchとbluetoothで接続ができている状態で使う
# frozen_string_literal: true

require "timeout"
require 'bundler/inline'
require "bundler/setup"
require "switch_connection_manager"

gemfile do
  source 'https://rubygems.org'
  git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }
  gem 'pry'
end

class ReadTimeoutError < StandardError; end

def procon
  return @procon if defined?(@procon)

  if path = SwitchConnectionManager::DeviceProconFinder.find
    puts "Use #{path} as procon's device file"
    return @procon = File.open(path, "w+b")
  else
    puts "fuck"
    exit 1
  end
end

def write(data)
  puts(">>> #{data}")
  procon.write_nonblock([data].pack("H*"))
end

def non_blocking_read
  read_once
rescue IO::EAGAINWaitReadable
  retry
end

# @raise [IO::EAGAINWaitReadable]
def read_once
  raw_data = procon.read_nonblock(64)
  puts("<<< #{raw_data.unpack("H*").first}")
  return raw_data
end

def blocking_read_with_timeout
  Timeout.timeout(4) do
    raw_data = procon.read(64)
    puts("<<< #{raw_data.unpack("H*").first}")
    return raw_data
  end
end

def non_blocking_read_with_timeout
  timeout = Time.now + 1

  begin
    read_once
  rescue IO::EAGAINWaitReadable
    raise(ReadTimeoutError) if timeout < Time.now
    retry
  end
end

def drain_all
  write("8005")
  20.times do
    non_blocking_read_with_timeout
  end
rescue ReadTimeoutError
end

class InvalidProcotol < StandardError; end

def connect_with_retry!
  begin
    write("0000")
    write("0000")
    write("8005")
    write("0000")
    write("8001")
    blocking_read_with_timeout
    write("8002")
    blocking_read_with_timeout
    write "01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000"
    raw_data = blocking_read_with_timeout
    if(data = raw_data.unpack("H*").first) && !(data =~ /^21/)
      puts "想定外の値が返ってきたのでretryします"
      raise InvalidProcotol
    end
  rescue InvalidProcotol
    drain_all
    retry
  end

  write "8004"

  20.times do
    non_blocking_read_with_timeout
  end
end

def connect_with_recover!
  write("0000")
  write("0000")
  write("8005")
  write("0000")
  write("8001")
  blocking_read_with_timeout # <<< 8101
  write("8002")
  blocking_read_with_timeout # <<< 8102
  write "01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000"

  raw_data = blocking_read_with_timeout
  case(data = raw_data.unpack("H*").first)
  when /^21/
    write "8004"

    write "0102000000000000000038F1F"
    write "0103000000000000000038F1F"
    write "0104000000000000000038F1F"
    write "0105000000000000000038F1F"
  when /^81/
    puts "(special route)"
    blocking_read_with_timeout # <<< 810100032dbd42e9b698000
    write("8002")
    blocking_read_with_timeout
    write "01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000"
    blocking_read_with_timeout
    write "8004"

    write "0102000000000000000038F1F"
    write "0103000000000000000038F1F"
    write "0104000000000000000038F1F"
    write "0105000000000000000038F1F"
  else
    raise "unkown patarren"
  end

  20.times do
    non_blocking_read_with_timeout
  end
end


connect_with_recover!


drain_all
exit

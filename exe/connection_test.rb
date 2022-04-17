#!/usr/bin/env ruby
# frozen_string_literal: true

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

def non_blocking_read_with_timeout
  timeout = Time.now + 4

  begin
    read_once
  rescue IO::EAGAINWaitReadable
    raise(ReadTimeoutError) if timeout < Time.now
    retry
  end
end


write("0000")
write("0000")
write("8005")
write("0000")
write("8001")
write "010e00000000000000004001"
write "010000000000000000000330"
write "010200000000000000003801"
write "8004"

199.times do
  non_blocking_read_with_timeout
end


#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "switch_connection_manager"

def procon
  return @procon if defined?(@procon)
  if path = SwitchConnectionManager::DeviceProconFinder.find
    @procon = File.open(path, "w+b")
  else
    print "fuck"
    exit 1
  end
end

def write(data)
  procon.write([data].pack("H*"))
end

def non_blocking_read
  read_once
rescue IO::EAGAINWaitReadable
  retry
end

# @raise [IO::EAGAINWaitReadable]
def read_once
  raw_data = procon.read_nonblock(64)
  to_stdout("<<< #{raw_data.unpack("H*").first}")
  return raw_data
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

write "01010001404000014040033f"

10.times do
  non_blocking_read_with_timeout
end

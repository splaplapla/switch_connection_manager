#!/usr/bin/env ruby
# frozen_string_literal: true
require "pry"

MAC_ADDR = '00005e00535e'
UART_INITIAL_INPUT = '81008000f8d77a22c87b0c'

def read_once(data)
  raw_data = [data].pack("H*")
  first_data_part = raw_data[0].unpack("H*").first

  return if first_data_part == "10" && raw_data.size == 10

  case first_data_part
  when "00", "80"
    data = raw_data.unpack("H*").first
    case data
    when "0000", "8005"
      return nil
    when "8001"
      response(
        make_response("81", "01", "0003#{MAC_ADDR}")
      )
    when "8002"
      response("8102")
      response("01000000000000000000033")
      response("21e791008000a7577240f8740b8003")
    when "8004"
      start_procon_simulator_thread
      return nil
    else
      puts "#{raw_data.unpack("H*").first} is unknown!!!!!!(1)"
    end
  when "01"
    sub_command = raw_data[10].unpack("H*").first
    case sub_command
    when "01" # Bluetooth manual pairing
      uart_response("81", sub_command, "03")
    when "02" # Request device info
      uart_response("82", sub_command, "03480302#{MAC_ADDR.reverse}0301")
    when "03", "08", "30", "38", "40", "48" # 01-03, 01-8, 01-30, 01-38, 01-40, 01-48
      uart_response("80", sub_command, [])
    when "04" # Trigger buttons elapsed time
      uart_response("83", sub_command, [])
    when "21" # Set NFC/IR MCU configuration
      uart_response("a0", sub_command, "0100ff0003000501")
    when "10"
      arg = raw_data[11..12].unpack("H*").first
      case arg
      when "0060" # Serial number
        spi_response(arg, 'ffffffffffffffffffffffffffffffff')
      when "5060" # Controller Color
        spi_response(arg, 'bc114 275a928 ffffff ffffff ff'.gsub(" ", "")) # Raspberry Color
      when "8060" # Factory Sensor and Stick device parameters
        spi_response(arg, '50fd0000c60f0f30619630f3d41454411554c7799c333663')
      when "9860" # Factory Stick device parameters 2
        spi_response(arg, '0f30619630f3d41454411554c7799c333663')
      when "1080" # User Analog sticks calibration
        spi_response(arg, 'ffffffffffffffffffffffffffffffffffffffffffffb2a1')
      when "3d60" # Factory configuration & calibration 2
        spi_response(arg, 'ba156211b87f29065bffe77e0e36569e8560ff323232ffffff')
      when "2880" # User 6-Axis Motion Sensor calibration
        spi_response(arg, 'beff3e00f001004000400040fefffeff0800e73be73be73b')
      else
        puts "#{first_data_part}-#{sub_command}-#{arg} is unknown!!!!!!(2)"
      end
    end
  else
    puts "#{first_data_part} is unknown!!!!!!(3)"
  end
end

# @return [String] switchに入力する用の128byte data
def make_response(code, cmd, buf)
  buf = [code, cmd, buf].join
  buf.ljust(128, "0")
end

def spi_response(addr, data)
  buf = [addr, "00", "00", "10", data].join
  uart_response("90", "10", buf)
end

def uart_response(code, subcmd, data)
  buf = [UART_INITIAL_INPUT, code, subcmd, data].join
  response(make_response("21", response_counter, buf))
end

def input_response
  response(make_response("30", response_counter, "98100800078c77448287509550274ff131029001b0022005a0271ff191028001e00210064027cff1410280020002100000000000000000000000000000000"))
end

def response(data)
  puts data
end

# @return [String]
def response_counter
  @response_counter = @response_counter + 1
  if @response_counter >= 256
    @response_counter = 0
  end

  @response_counter.to_s(16).rjust(2, "0")
end

@response_counter = 0


data = ARGV[0] or raise "need arg"
read_once(data)


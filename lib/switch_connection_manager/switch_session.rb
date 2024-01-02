class SwitchConnectionManager::SwitchSession
  class ReadTimeoutError < StandardError; end

  attr_accessor :gadget

  MAC_ADDR = '176d96e7a548'

  UART_INITIAL_INPUT = '81008000f8d77a22c87b0c'

  # @param [String, nil] mac_addr
  # @param [File, nil] procon_file
  def initialize(mac_addr: nil, procon_file: nil)
    @response_counter = 0
    @procon_simulator_thread = nil
    @mac_addr = mac_addr || MAC_ADDR
    @procon_file = procon_file
  end

  def prepare!
    @gadget = find_gadget_devices

    log("prepare! start")
    loop do
      read_once
      break if @finish_prepare
    end
    log("prepare! finished")
  end

  def device
    @gadget
  end

  def read_once
    raw_data = non_blocking_read_with_timeout
    first_data_part = raw_data[0].unpack("H*").first

    return if first_data_part == "10" && raw_data.size == 10

    case first_data_part
    when "00", "80"
      data = raw_data.unpack("H*").first
      case data
      when "0000", "8005"
        return nil
      when "8001"
        responseo_to_switch(
          make_response("81", "01", "0003#{@mac_addr}")
        )
      when "8002"
        responseo_to_switch("8102")
      when "8004"
        @finish_prepare = true
        return
      else
        puts "#{raw_data.unpack("H*").first} is unknown!!!!!!(1)"
      end
    when "01"
      sub_command = raw_data[10].unpack("H*").first
      case sub_command
      when "01" # Bluetooth manual pairing
        uart_response("81", sub_command, "03")
      when "02" # Request device info
        uart_response("82", sub_command, "03480302#{@mac_addr.reverse}0301")
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
      puts "#{first_data_part}} is unknown!!!!!!(3)"
    end
  end

  def shutdown
    @terminated = true
    @gadget.close
  end

  def terminated?
    @terminated
  end

  private

  def non_blocking_read
    data = gadget.read_nonblock(64)
    log("[switch] >>> #{data.unpack("H*").first}")
    data
  end

  def non_blocking_read_with_timeout
    timeout = Time.now + 10

    begin
      non_blocking_read
    rescue IO::EAGAINWaitReadable
      raise(ReadTimeoutError) if timeout < Time.now

      retry
    end
  end

  def spi_response(addr, data)
    buf = [addr, "00", "00", "10", data].join
    uart_response("90", "10", buf)
  end

  def uart_response(code, subcmd, data)
    buf = [UART_INITIAL_INPUT, code, subcmd, data].join
    responseo_to_switch(
      make_response("21", response_counter, buf)
    )
  end

  # @return [String] switchに入力する用の128byte data
  def make_response(code, cmd, buf)
    buf = [code, cmd, buf].join
    buf.ljust(128, "0")
  end

  def responseo_to_switch(data)
    write(data)
    data
  end

  # @return [String]
  def response_counter
    @response_counter = @response_counter + 1
    if @response_counter >= 256
      @response_counter = 0
    end

    @response_counter.to_s(16).rjust(2, "0")
  end

  def write(data)
    log("<<< #{data}")
    @gadget.write_nonblock([data].pack("H*"))
  rescue IO::EAGAINWaitReadable
    retry
  end

  def start_procon_simulator_thread
    @procon_simulator_thread =
      Thread.start do
        loop do
          break if switch_session.terminated?

          any_input_response
          sleep(0.03)
        rescue IO::EAGAINWaitReadable
          retry
        end
      end
  end

  def find_gadget_devices
    SwitchConnectionManager::UsbDeviceController.reset
    SwitchConnectionManager::UsbDeviceController.init

    system('sudo chmod 777 -R /sys/kernel/config/usb_gadget/procon')
    system('sudo chmod 777 /dev/hidg0')
    @gadget = File.open('/dev/hidg0', "w+b")
  end

  def log(text)
    puts(text)
  end

  def debug_log(text)
    puts("[debug] #{text}") if ENV["VERBOSE"]
  end

  def any_input_response
    responseo_to_switch(
      make_response("30", response_counter, "98100800078c77448287509550274ff131029001b0022005a0271ff191028001e00210064027cff1410280020002100000000000000000000000000000000")
    )
  end
end

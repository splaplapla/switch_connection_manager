# 対プロコンに接続してボタンなどの入力を読み取る
class SwitchConnectionManager::Procon
  class ReadTimeoutError < StandardError; end
  # NOTE 現時点では、bluetoothでつながっている状態で実行するとジャイロも動くようになる
  # TODO switchと接続していない状態でもジャイロを動くようにする

  CONFIGURATION_STEPS = [
    "01000000000000000000480000000000000000000000000000000000000000000000000000000000000000000000000000", # 01-48
    "01010000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000", # 01-02 device request
    "01020000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000", # 01-08 Set shipment low power state
    "01030000000000000000100060000010000000000000000000000000000000000000000000000000000000000000000000", # 01-10-0060, Serial number
    "0104000000000000000010506000000d000000000000000000000000000000000000000000000000000000000000000000", # 01-10-5060, Controller Color
    "0105000000000000000001044c748786451c00043c4e696e74656e646f2053776974636800000000006800c0883cd37900", # 01-01, Bluetooth manual pairing
    "01070000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000", # 01-04, Trigger buttons elapsed time
    "01080000000000000000108060000018000000000000000000000000000000000000000000000000000000000000000000", # 01-10-8060, Factory Sensor and Stick device parameters
    "01090000000000000000109860000012000000000000000000000000000000000000000000000000000000000000000000", # 01-10-9860, Factory Stick device parameters 2
    "010a0000000000000000101080000018000000000000000000000000000000000000000000000000000000000000000000", # 01-10-1080, User Analog sticks calibration
    "010c0000000000000000103d60000019000000000000000000000000000000000000000000000000000000000000000000", # 01-10-3d60, Factory configuration & calibration 2
    "010d0000000000000000102880000018000000000000000000000000000000000000000000000000000000000000000000", # 01-10-2880, User 6-Axis Motion Sensor calibration
    # "010e00000000000000004001", # 01-40. 01-03-30で有効化するので不要
    # "010000000000000000004800", # vibration
    # "0101000000000000000030f0", # led
    # "010200000000000000003801", # home button led
  ]

  attr_accessor :procon

  def initialize
    @status = SwitchConnectionManager::ProconConnectionStatus.new
    @input_report_receiver_thread = nil
    @connected_step_index = 0
    @configuration_steps = []
    @internal_status = SwitchConnectionManager::ProconInternalStatus.new
    # 1.times { CONFIGURATION_STEPS.each { |x| @configuration_steps << x } } # もう動かない
    SwitchConnectionManager::ProconInternalStatus::SUB_COMMANDS_ON_START.each do |step|
      @configuration_steps << step
    end
  end

  def run
    init_devices

    at_exit do
      $terminated = true
      if procon
        begin
          non_blocking_read_with_timeout
        rescue ReadTimeoutError
        end
        send_to_procon("8005")
        send_to_procon("010200000000000000003800") # off home bottun led
        4.times do
          non_blocking_read_with_timeout
        rescue ReadTimeoutError
        end
        procon.close
      end
    end

    loop do
      do_once
    end
  end

  def do_once
    if @status.disconnected?
      send_initialize_data
      @status.sent_initialize_data!
      return nil
    end

    if @status.sent_initialize_data?
      raw_data = non_blocking_read_with_timeout
      data = raw_data.unpack("H*").first

      case data
      when /^8101/ # 810100032dbd42e9b69800 的なやつがくる
        return send_to_procon "8002"
      when /^8102/
        return send_to_procon "010100000000000000000330"
      when /^21.+?8003000/

        loop do
          if @internal_status.has_unreceived_command?
            send_to_procon(@internal_status.unreceived_byte)
          else
            if(configuration_step = @configuration_steps.shift)
              @internal_status.mark_as_send(step: configuration_step)
              send_to_procon(@internal_status.byte_of(step: configuration_step))
            else
              break
            end
          end

          begin
            raw_data = non_blocking_read_with_timeout
            @internal_status.receive(raw_data: raw_data)
          rescue ReadTimeoutError
            print "."
          end
        end

        out = send_to_procon "8004"
        start_input_report_receiver_thread
        @status.connected!
        return out
      else
        return
      end
    end

    connection_sleep
  rescue ReadTimeoutError
    @status.reset!
    retry
  end

  def send_initialize_data
    send_to_procon("0000")
    send_to_procon("0000")
    send_to_procon("8005")
    send_to_procon("0000")
    send_to_procon("8001")
  end

  def send_to_procon(data)
    write(data)
    return data
  end

  private

  def write(data)
    to_stdout(">>> #{data}")
    @procon.write_nonblock([data].pack("H*"))
  rescue IO::EAGAINWaitReadable
    retry
  rescue Errno::EINVAL => e
    puts e.message
    sleep(1)
    retry
  end

  def init_devices
    if path = SwitchConnectionManager::DeviceProconFinder.find
      @procon = File.open(path, "w+b")
      puts "Use #{path} as procon's device file"
    else
      raise "not found procon error" # TODO erro class
    end
  end

  def to_stdout(text)
    puts(text)
  end

  # @raise [IO::EAGAINWaitReadable]
  def read_once
    raw_data = procon.read_nonblock(64)
    to_stdout("<<< #{raw_data.unpack("H*").first}")
    return raw_data
  end

  def non_blocking_read
    read_once
  rescue IO::EAGAINWaitReadable
    retry
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

  def blocking_read
    raw_data = procon.read(64)
    to_stdout("<<< #{raw_data.unpack("H*").first}")
    return raw_data
  end

  def connection_sleep
    sleep(1)
  end

  def start_input_report_receiver_thread
    sleep(0.5)
    @input_report_receiver_thread =
      Thread.start do
        break if $terminated
        loop do
          begin
            raw_data = non_blocking_read_with_timeout
          rescue ReadTimeoutError
            print "."
          end
        end
      end
  end
end

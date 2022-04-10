# 対プロコンに対して使う用です
class SwitchConnectionManager::Procon
  class Status
    attr_accessor :value

    def initialize
      @value = :disconnected
    end

    def sent_initialize_data?
      @value == :sent_initialize_data
    end

    def disconnected?
      @value == :disconnected
    end

    def connected?
      @value == :connected
    end

    def sent_initialize_data!
      @value = :sent_initialize_data
      puts "Change status to sent_initialize_data"
    end

    def connected!
      @value == :connected
      puts "Change status to connected"
    end
  end

  class AlreadyConnectedError < StandardError; end
  # NOTE 現時点では、bluetoothでつながっている状態で実行するとジャイロも動くようになる
  # TODO 切断したらstatusをdisconnectedにする
  # TODO switchと接続していない状態でもジャイロを動くようにする

  CONFIGURATION_STEPS = [
    "01000000000000000000480000000000000000000000000000000000000000000000000000000000000000000000000000", # 01-48
    "01010000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000", # 01-02
    "01020000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000", # 01-08
    "01030000000000000000100060000010000000000000000000000000000000000000000000000000000000000000000000", # 01-10-0060, Serial number
    "0104000000000000000010506000000d000000000000000000000000000000000000000000000000000000000000000000", # 01-10-5060, Controller Color
    "0105000000000000000001044c748786451c00043c4e696e74656e646f2053776974636800000000006800c0883cd37900", # 01-01, Bluetooth manual pairing
    "01070000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000", # 01-04, Trigger buttons elapsed time
    "01080000000000000000108060000018000000000000000000000000000000000000000000000000000000000000000000", # 01-10-8060, Factory Sensor and Stick device parameters
    "01090000000000000000109860000012000000000000000000000000000000000000000000000000000000000000000000", # 01-10-9860, Factory Stick device parameters 2
    "010a0000000000000000101080000018000000000000000000000000000000000000000000000000000000000000000000", # 01-10-1080, User Analog sticks calibration
    "010c0000000000000000103d60000019000000000000000000000000000000000000000000000000000000000000000000", # 01-10-3d60, Factory configuration & calibration 2
    "010d0000000000000000102880000018000000000000000000000000000000000000000000000000000000000000000000", # 01-10-2880, User 6-Axis Motion Sensor calibration
    "010e0000000000000000400100000000000000000000000000000000000000000000000000000000000000000000000000", # 01-40
    "01000000000000000000480100000000000000000000000000000000000000000000000000000000000000000000000000",
    "01010001404000014040480100000000000000000000000000000000000000000000000000000000000000000000000000",
    "01020000000000000000300100000000000000000000000000000000000000000000000000000000000000000000000000",
  ]

  attr_accessor :procon

  def initialize
    @status = Status.new
    @input_report_receiver_thread = nil
    @connected_step_index = 0
    @configuration_steps = CONFIGURATION_STEPS.dup + CONFIGURATION_STEPS.dup
  end

  def run
    init_devices

    at_exit do
      if procon
        send_initialize_data
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
      raw_data = read
      data = raw_data.unpack("H*").first

      case data
      when /^810103000000000000/
        # 再接続した時にこれを受け取ることがある
        return send_to_procon "01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000"
      when /^81010003/ # 810100032dbd42e9b69800 的なやつがくる
        return send_to_procon "8002"
      when /^810200000000000000000000000000000000000000000000000000/
        return send_to_procon "01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000"
      when /^21.+?8003000/
        out = send_to_procon "8004"
        10.times do
          begin
            read_once
          rescue IO::EAGAINWaitReadable
            sleep(0.2)
          end
        end
        start_input_report_receiver_thread
        @status.connected!
        return out
      else
        nonblocking_read
      end
    end

    if (configuration_step = @configuration_steps.shift)
      send_to_procon(configuration_step)
      begin
        read_once
      rescue IO::EAGAINWaitReadable
      end

      return
    else
      # send_to_procon("100f0001404000014040")
      connection_sleep
      return
    end
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

  def read
    read_once
  rescue IO::EAGAINWaitReadable
    retry
  end

  def nonblocking_read
    read
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
    sleep(1)
    @input_report_receiver_thread =
      Thread.start do
        loop do
          blocking_read
        rescue IO::EAGAINWaitReadable
          sleep(0.03)
          retry
        end
      end
  end
end

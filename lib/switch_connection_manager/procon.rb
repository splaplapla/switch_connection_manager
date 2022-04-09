# 対プロコンに対して使う用です
class SwitchConnectionManager::Procon
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
    "100b0001404000014040", # unkown
    "010c0000000000000000103d60000019000000000000000000000000000000000000000000000000000000000000000000", # 01-10-3d60, Factory configuration & calibration 2
    "010d0000000000000000102880000018000000000000000000000000000000000000000000000000000000000000000000", # 01-10-2880, User 6-Axis Motion Sensor calibration
    "010e0000000000000000400100000000000000000000000000000000000000000000000000000000000000000000000000", # 01-40
    "100f0001404000014040", # unkown
    "01000000000000000000480100000000000000000000000000000000000000000000000000000000000000000000000000",
    "01010001404000014040480100000000000000000000000000000000000000000000000000000000000000000000000000",
    "01020000000000000000300100000000000000000000000000000000000000000000000000000000000000000000000000",
  ]

  attr_accessor :procon

  def initialize
    @status = :disconnected
    @input_report_receiver_thread = nil
    @connected_step_index = 0
    @configuration_steps = CONFIGURATION_STEPS.dup
  end

  def run
    init_devices

    loop do
      do_once
    rescue AlreadyConnectedError
      sleep(2)
    end
  end

  def do_once
    if @status == :disconnected
      send_initialize_data
      @status = :sent_initialize_data
      return nil
    end

    if @status == :sent_initialize_data
      raw_data = read
      data = raw_data.unpack("H*").first
      case data
      when /^8101/
        return send_to_procon "8002"
      when /^8102/
        return send_to_procon "01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000"
      when /^21.+?8003000/
        out = send_to_procon "8004"
        start_input_report_receiver_thread
        @status = :connected
        return out
      end
    end

    if @status == :connected
      configuration_step = @configuration_steps.shift
      send_to_procon(configuration_step)
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

  def read
    raw_data = procon.read_nonblock(64)
    to_stdout("<<< #{raw_data.unpack("H*").first}")
    return raw_data
  rescue IO::EAGAINWaitReadable
    retry
  end

  def blocking_read
    raw_data = procon.read(64)
    to_stdout("<<< #{raw_data.unpack("H*").first}")
    return raw_data
  rescue IO::EAGAINWaitReadable
    retry
  end

  def start_input_report_receiver_thread
    @input_report_receiver_thread =
      Thread.start do
        loop do
          blocking_read
          sleep(0.03)
        rescue IO::EAGAINWaitReadable
          retry
        end
      end
  end
end
# 対プロコンに対して使う用です
class SwitchConnectionManager::SwitchSimulatorForProcon
  class AlreadyConnectedError < StandardError; end

  STEPS = [
    :disconnected,
    :sent_initialize_data,
    :connected
  ]

  attr_accessor :procon

  def initialize
    @status = :disconnected
    @input_report_receiver_thread = nil
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
    if @status == :connected
      raise AlreadyConnectedError
    end

    if @status == :disconnected
      send_initialize_data
      @status = :sent_initialize_data
      return nil
    end

    raw_data = read
    case first_data_part = raw_data[0..1].unpack("H*").first
    when "8101"
      response "8002"
    when "8102"
      response "01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000"
    when /^21\d/
      out = response "8004"
      start_input_report_receiver_thread
      @status = :connected
      return out
    end
  end

  def send_initialize_data
    write("0000")
    write("0000")
    write("8005")
    write("0000")
    write("8001")
  end

  def response(data)
    write(data)
    return data
  end

  private

  def read
    to_stdout("<<< #{data}")
    procon.read_nonblock(64)
  rescue IO::EAGAINWaitReadable
    retry
  end

  def write(data)
    to_stdout(">>> #{data}")
    @gadget.write_nonblock([data].pack("H*"))
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

  def start_input_report_receiver_thread
    @input_report_receiver_thread =
      Thread.start do
        loop do
          read
          sleep(0.03)
        rescue IO::EAGAINWaitReadable
          retry
        end
      end
  end
end

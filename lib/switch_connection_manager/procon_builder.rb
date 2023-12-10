class SwitchConnectionManager::ProconBulder
  class ProconDevice
    def initialize(procon_file)
      @procon_file = procon_file
      @status = SwitchConnectionManager::ProconConnectionStatus.new
    end

    def build
      loop do
        do_once
      end
    end

    private

    def non_blocking_read
      raw_data = procon.read_nonblock(64)
      to_stdout("<<< #{raw_data.unpack1('H*')}")
      raw_data
    end

    def send_initialize_data
      send_to_procon("8006") # 最初に送ると安定するっぽい？（検証が必要）
      send_to_procon('0000')
      send_to_procon('0000')
      send_to_procon('8005')
      send_to_procon('0000')
      send_to_procon('8001')
    end

    def send_to_procon(data)
      write(data)
      data
    end

    def write(data)
      to_stdout(">>> #{data}")
      @procon.write_nonblock([data].pack('H*'))
    rescue IO::EAGAINWaitReadable
      retry
    rescue Errno::EINVAL => e
      puts e.message
      sleep(1)
      retry
    end
  end

  def initialize(procon_file)
    @procon_file = procon_file
  end

  def build
    procon_device = ProconDevice.new(@procon_file)

    procon_device.build
    procon_device
  end
end

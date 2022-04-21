class SwitchConnectionManager::Mouse
  def Device
    def read
      blocking_read
    end

    def blocking_read
      raw_data = mouse.read(16)
      to_stdout("<<< #{raw_data.unpack("H*").first}")
      return raw_data
    end

    private

    def non_blocking_read
      raw_data = mouse.read_nonblock(32)
      to_stdout("<<< #{raw_data.unpack("H*").first}")
      return raw_data
    rescue IO::EAGAINWaitReadable
      sleep(0.05)
    end

    def mouse
      path = SwitchConnectionManager::MouseFinder.find or raise("device could not find")
      @mouse ||= File.open(path, "w+b")
    end

    def to_stdout
      puts(text)
    end
  end

  class DataParser < Struct.new(:tv_sec, :tv_usec, :type, :code, :value)
    def self.parse(raw_data)
      new.parse(raw_data)
    end

    def parse(data)
      DataParser.new(*data.unpack("llSSl"))
    end
  end

  def run
    device = Device.new

    loop do
      raw_data = device.read
      DataParser.parse(raw_data)
    end
  end
end

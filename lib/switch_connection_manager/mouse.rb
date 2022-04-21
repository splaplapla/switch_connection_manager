class SwitchConnectionManager::Mouse
  def run
    loop do
      blocking_read
    end
  end

  private

  def blocking_read
    raw_data = mouse.read(64)
    to_stdout("<<< #{raw_data.unpack("H*").first}")
    return raw_data
  end

  def mouse
    path = SwitchConnectionManager::MouseFinder.find or raise("device could not find")
    @mouse ||= File.open(path, "w+b")
  end
end

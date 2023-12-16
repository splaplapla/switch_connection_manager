class SwitchConnectionManager::ProconConnectionStatus
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
    puts 'Change status to sent_initialize_data'
  end

  def connected!
    @value = :connected
    puts 'Change status to connected'
  end

  def reset!
    @value = :disconnected
    puts 'Change status to disconnected, because stuck'
  end
end

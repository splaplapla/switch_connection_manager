class SwitchConnectionManager::ProconInternalStatus
  class HIDSubCommandRequest
    def initialize(counter: , sub_command: , arg: )
      @counter =  counter
      @sub_command = sub_command
      @arg = arg
    end

    def to_byte
      [["01", "0", @counter, "00" * 8, @sub_command, @arg].join].pack("H*")
    end
  end

  class HIDSubCommandResponse
    attr_accessor :sub_command

    def self.parse(data)
      if sub_command = data[28..29]
        new(sub_command: sub_command)
      else
        raise "could not parse"
      end
    end

    def initialize(sub_command: )
      @sub_command = sub_command
    end
  end


  attr_accessor :counter
  attr_accessor :player_light, :home_button_light

  SUB_COMMANDS = [
    # "18", # SPI read. not support
    # "12",
    ["30", "01"], # player_light
    ["38", "01"], # home_button_light
  ]

  SUB_COMMANDS_ON_START = [
    :enable_player_light,
    :enable_home_button_light,
  ]

  SUB_COMMANDS_NAME_TABLE = {
    enable_player_light: :player_light,
    disable_player_light: :player_light,
    enable_home_button_light: :home_button_light,
    disable_home_button_light: :home_button_light,
  }

  SUB_COMMANDS_ID_TABLE = {
    "30" => :player_light,
    "38" => :home_button_light,
  }

  SUB_COMMAND_STATUS_SENT = :sent
  SUB_COMMAND_STATUS_RECEIVED_ACK = :received_ack

  def initialize
    @counter = 0
    @send_sub_command_map = {}
  end

  def byte_of(step: )
    public_send(step)
  end

  def mark_as_send(step: )
    name = SUB_COMMANDS_NAME_TABLE[step]
    @send_sub_command_map[name] = [SUB_COMMAND_STATUS_SENT]
  end

  def enable_player_light
    HIDSubCommandRequest.new(counter: @counter, sub_command: "30", arg: "01").to_byte
  end

  def disable_player_light
    HIDSubCommandRequest.new(counter: @counter, sub_command: "30", arg: "00").to_byte
  end

  def enable_home_button_light
    HIDSubCommandRequest.new(counter: @counter, sub_command: "38", arg: "01").to_byte
  end

  def disable_home_button_light
    HIDSubCommandRequest.new(counter: @counter, sub_command: "38", arg: "00").to_byte
  end

  def receive(raw_data: )
    data = raw_data.unpack("H*").first
    case data
    when /^21/
      response = HIDSubCommandResponse.parse(data)
      step = SUB_COMMANDS_ID_TABLE[response.sub_command]
      @send_sub_command_map[step] << SUB_COMMAND_STATUS_RECEIVED_ACK
    end
  end

  def received?(step: )
    name = SUB_COMMANDS_NAME_TABLE[step]
    @send_sub_command_map[name]&.include?(SUB_COMMAND_STATUS_RECEIVED_ACK)
  end

  private

  def increment_counter
    @counter = @counter + 1
    if @counter >= 256
      @counter = "0"
    else
      @counter.to_s
    end
  end
end

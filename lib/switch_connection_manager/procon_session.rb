# 対プロコンに接続してボタンなどの入力を読み取る
class SwitchConnectionManager::ProconSession
  class ReadTimeoutError < StandardError; end
  class ProconNotFound < StandardError; end

  attr_accessor :procon, :mac_addr

  def initialize
    @procon_connection_status = SwitchConnectionManager::ProconConnectionStatus.new
    @configuration_steps = []
    @prebypass_connection_status = SwitchConnectionManager::ProconInternalStatus.new
    SwitchConnectionManager::ProconInternalStatus::SUB_COMMANDS_ON_START.each do |step|
      @configuration_steps << step
    end
  end

  # @return [void]
  def prepare!
    @procon = find_procon_device

    loop do
      is_finished = read_once
      break if is_finished
    end

    return unless @mac_addr.nil?

    raise '接続が完了していたらmac_addrがセットされているべき'
  end

  # @return [void] ブロッキングする
  def read_and_print
    sleep(0.5)
    loop do
      break if @terminated

      non_blocking_read_with_timeout
    rescue ReadTimeoutError
      print '.'
    end
  end

  # @return [File]
  def device
    procon
  end

  def shutdown
    return unless procon

    SwitchConnectionManager.logger.info('Shutdown procon')

    @terminated = true

    # 未送信のデータを吐き出す。いらないかも
    begin
      non_blocking_read_with_timeout
    rescue ReadTimeoutError
    end
    # send_to_procon('8005')
    send_to_procon('010200000000000000003800') # off home bottun led
    send_to_procon('010500000000000000003800')
    send_to_procon('010600000000000000003800')
    send_to_procon('010700000000000000003800')
    send_to_procon('010800000000000000003800')

    SwitchConnectionManager.logger.info('starting drain')
    send_to_procon('0100000000000000000007000000000000000000000000000000000000000000') # Reset pairing info
    send_to_procon('0101000000000000000007000000000000000000000000000000000000000000') # Reset pairing info
    # 未送信のデータを吐き出す。いらないかも
    10.times do
      begin
        non_blocking_read
      rescue IO::EAGAINWaitReadable
        print '.'
      end
    end

    procon.close

    SwitchConnectionManager.logger.info('Shutdown procon finished')
  end

  def non_blocking_read_with_timeout
    timeout = Time.now + 1

    begin
      non_blocking_read
    rescue IO::EAGAINWaitReadable
      raise(ReadTimeoutError) if timeout < Time.now

      retry
    end
  end

  def read_once
    if @procon_connection_status.disconnected?
      send_initialize_data
      @procon_connection_status.sent_initialize_data!
      return
    end

    if @procon_connection_status.sent_initialize_data?
      raw_data = non_blocking_read_with_timeout
      data = raw_data.unpack1('H*')

      case data
      when /^8101/ # 810100032dbd42e9b69800 的なやつがくる
        write_mac_addr(data)
        send_to_procon '8002'
        nil
      when /^8102/
        send_to_procon '010100000000000000000330'
        nil
      when /^21.+?8003000/
        loop do
          if @prebypass_connection_status.has_unreceived_command?
            send_to_procon(@prebypass_connection_status.unreceived_byte)
          else
            break unless (configuration_step = @configuration_steps.shift)

            @prebypass_connection_status.mark_as_send(step: configuration_step)
            send_to_procon(@prebypass_connection_status.byte_of(step: configuration_step))
          end

          begin
            raw_data = non_blocking_read_with_timeout
            @prebypass_connection_status.receive(raw_data:)
          rescue ReadTimeoutError
            print '.'
          end
        end

        send_to_procon '8004'
        @procon_connection_status.connected!
        true
      end
    end
  rescue ReadTimeoutError
    @procon_connection_status.reset!
    SwitchConnectionManager.logger.info "[read timeout] #{@procon_connection_status.value}"
    send_to_procon('8006') # タイムアウトをしたらこれでリセットが必要
    send_to_procon('0100000000000000000007000000000000000000000000000000000000000000') # Reset pairing info
    retry
  end

  private

  def write(data)
    to_stdout(">>> #{data}")
    @procon.write_nonblock([data].pack('H*'))
  rescue IO::EAGAINWaitReadable
    retry
  rescue Errno::EINVAL => e
    SwitchConnectionManager.logger.error e.message
    sleep(1)
    retry
  end

  # @return [File]
  def find_procon_device
    raise ProconNotFound, 'not found procon error' unless (path = SwitchConnectionManager::DeviceProconFinder.find)

    SwitchConnectionManager.logger.info "Use #{path} as procon's device file"
    `sudo chmod 777 #{path}`
    File.open(path, 'w+b')
  end

  def to_stdout(text)
    SwitchConnectionManager.logger.debug(text)
  end

  # @raise [IO::EAGAINWaitReadable]
  def non_blocking_read
    raw_data = procon.read_nonblock(64)
    to_stdout("<<< #{raw_data.unpack1('H*')}")
    raw_data
  end

  def blocking_read
    raw_data = procon.read(64)
    to_stdout("<<< #{raw_data.unpack1('H*')}")
    raw_data
  end

  def send_initialize_data
    # https://github.com/dekuNukem/Nintendo_Switch_Reverse_Engineering/blob/master/bluetooth_hid_subcommands_notes.md#subcommand-0x07-reset-pairing-info
    # send_to_procon('0100000000000000000007000000000000000000000000000000000000000000') # Reset pairing info
    # send_to_procon('0101000000000000000007000000000000000000000000000000000000000000') # Reset pairing info
    # send_to_procon('0102000000000000000007000000000000000000000000000000000000000000') # Reset pairing info
    # send_to_procon('0000')

    # send_to_procon('0101000000000000000006020000000000000000000000000000000000000000') # Reset pairing info

    # send_to_procon('8006') # 最初に送ると安定するっぽい？（検証が必要）
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

  def write_mac_addr(data)
    unless /81010003(\w{12})/ =~ data
      "入力(#{data})はMACアドレスではない"

      SwitchConnectionManager.logger.warn("この入力はMACアドレスではない(#{data[0..10]})")
    end

    @mac_addr = ::Regexp.last_match(1)
  end
end

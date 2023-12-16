class MockProconDevice
  def initialize
    @latest_received = nil
  end

  def read_nonblock(*)
    value = case @latest_received
            when '8001'
              '810100032dbd42e9b69800'
            when '8002'
              '8102'
            when /01\w{2}00000000000000000330/
              '210181008000f8d77a22c87b0c800300000000000000000000000000000000000000000000000000000000000000000'
            when /01\w{2}00000000000000004800/
              '210181008000f8d77a22c87b0c804800000000000000000000000000000000000000000000000000000000000000000'
            when /01\w{2}0000000000000000381ff0ff/
              '210181008000f8d77a22c87b0c803800000000000000000000000000000000000000000000000000000000000000000'
            when '8004'
              '300098100800078c77448287509550274ff131029001b0022005a0271ff191028001e00210064027cff1410280020002100000000'
            when '010200000000000000003800' # NOTE: shutdownを呼ぶと書き込まれる
              '300098100800078c77448287509550274ff131029001b0022005a0271ff191028001e00210064027cff1410280020002100000000'
            else
              raise "unexpected value(latest_received: #{@latest_received})"
            end
    [value].pack('H*')
  end

  def write_nonblock(bytes)
    @latest_received = bytes.unpack1('H*')
  end

  def close; end
end

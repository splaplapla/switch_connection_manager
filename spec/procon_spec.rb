require "spec_helper"

describe SwitchConnectionManager::Procon do
  let(:simulator) { described_class.new }
  let(:initial_input) { SwitchConnectionManager::ProconSimulator::UART_INITIAL_INPUT }

  describe '#do_once' do
    before do
      allow(simulator).to receive(:connection_sleep)
      allow(simulator).to receive(:to_stdout)
    end

    it do
      allow(simulator).to receive(:write)
      expect(simulator).to receive(:start_input_report_receiver_thread).once
      allow(simulator).to receive(:read).and_return(
        ["8101000300005e00535e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"),
        ["81020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"),
        ["210#{initial_input}8003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"),
        ["210#{initial_input}8048000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"),
      )
      expect(simulator.do_once).to be_nil
      expect(simulator.do_once).to eq("8002")
      expect(simulator.do_once).to eq("01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000")
      expect(simulator.do_once).to eq("8004") # 8004を送った後
      expect(simulator.do_once).to eq(nil)
    end
  end
end

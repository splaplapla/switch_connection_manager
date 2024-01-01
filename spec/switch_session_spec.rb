require "spec_helper"

describe SwitchConnectionManager::SwitchSession do
  let(:initial_input) { SwitchConnectionManager::ProconSimulator::UART_INITIAL_INPUT }
  let(:procon_mac_addr) { SwitchConnectionManager::ProconSimulator::MAC_ADDR }
  let(:simulator) { described_class.new }

  describe '#response_counter' do
    it '255の次は0になること' do
      254.times do
        simulator.send(:response_counter)
      end
      expect(simulator.send(:response_counter)).to eq("255")
      expect(simulator.send(:response_counter)).to eq("0")
    end
  end

  describe '#read_once' do
    describe 'unit test' do
      before do
        allow(simulator).to receive(:write)
        allow(simulator).to receive(:to_stdout)
        allow(simulator).to receive(:read).and_return([subject_data].pack("H*"))
      end

      subject { simulator.read_once }

      shared_examples 'it_is_64bytes' do
        it { expect([subject].pack("H*").size).to eq(64) }
      end

      context '>>> 0000' do
        let(:subject_data) { "0000" }
        it { expect(subject).to be_nil }
      end

      context '>>> 8005' do
        let(:subject_data) { "8005" }
        it { expect(subject).to be_nil }
      end

      context '>>> 8001' do
        let(:subject_data) { "8001" }
        it { expect(subject).to match("8101000300005e00535e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000") }
        include_examples "it_is_64bytes"
      end

      context '>>> 8002' do
        let(:subject_data) { "8002" }
        it { expect(subject).to match("81020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000") }
        include_examples "it_is_64bytes"
      end

      context '>>> 10-03' do
        let(:subject_data) { "01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000" }
        it { expect(subject).to match((/^21.#{initial_input}8003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/)) }
        include_examples "it_is_64bytes"
      end

      context '>>> 8004' do
        let(:subject_data) { "8004" }
        it do
          expect(simulator).to receive(:start_procon_simulator_thread).once
          expect(subject).to be_nil
        end
      end

      context '>>> 01-48' do
        let(:subject_data) { "01000000000000000000480000000000000000000000000000000000000000000000000000000000000000000000000000" }
        it { expect(subject).to match((/^21.#{initial_input}804800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/)) }
        include_examples "it_is_64bytes"
      end

      context '>>> 01-02' do
        let(:subject_data) { "01010000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000" }
        it { expect(subject).to match((/^21.#{initial_input}820203480302#{procon_mac_addr.reverse}0301000000000000000000000000000000000000000000000000000000000000000000000000000/)) }
        include_examples "it_is_64bytes"
      end

      context '>>> 01-08' do
        let(:subject_data) { "01020000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000" }
        it { expect(subject).to match((/^21.#{initial_input}8008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/)) }
        include_examples "it_is_64bytes"
      end

      context '>>> 01-10-0060' do
        let(:subject_data) { "01030000000000000000100060000010000000000000000000000000000000000000000000000000000000000000000000" }
        it { expect(subject).to match((/^21.#{initial_input}90100060000010ffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000/)) }
        include_examples "it_is_64bytes"
      end
    end

    context '順番に呼び出すとき' do
      before do
        allow(simulator).to receive(:write)
        allow(simulator).to receive(:read).and_return(
          ["0000"].pack("H*"), # none
          ["0000"].pack("H*"), # none
          ["8005"].pack("H*"), # none
          ["0000"].pack("H*"), # none
          ["8001"].pack("H*"), # <<< 810100031f861dd6030400000000000000000000000000000 # procon
          ["8002"].pack("H*"), # <<< 8102...
          ["01000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-03
          ["8004"].pack("H*"), # <<< 309e810080007cc8788f28700a78fd0d00f90ff5ff0100080075fd0900f70ff5ff0200070071fd0900f70ff5ff02000700000000000000000000000000000000
          ["01000000000000000000480000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-48
          ["01010000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-02
          ["01020000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-08
          ["01030000000000000000100060000010000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-10-0060, Serial number
          ["0104000000000000000010506000000d000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-10-5060, Controller Color
          ["0105000000000000000001044c748786451c00043c4e696e74656e646f2053776974636800000000006800c0883cd37900"].pack("H*"), # 01-01, Bluetooth manual pairing
          ["01070000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-04, Trigger buttons elapsed time
          ["01080000000000000000108060000018000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-10-8060, Factory Sensor and Stick device parameters
          ["01090000000000000000109860000012000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-10-9860, Factory Stick device parameters 2
          ["010a0000000000000000101080000018000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-10-1080, User Analog sticks calibration
          ["100b0001404000014040"].pack("H*"), # unkown
          ["010c0000000000000000103d60000019000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-10-3d60, Factory configuration & calibration 2
          ["010d0000000000000000102880000018000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-10-2880, User 6-Axis Motion Sensor calibration
          ["010e0000000000000000400100000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-40
          ["100f0001404000014040"].pack("H*"), # unkown
          ["01000000000000000000480100000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-48
          ["01010001404000014040480100000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-48
          ["01020000000000000000300100000000000000000000000000000000000000000000000000000000000000000000000000"].pack("H*"), # 01-30
        )
      end

      it do
        expect(simulator).to receive(:start_procon_simulator_thread).once
        expect(simulator.read_once).to eq(nil) # 0000
        expect(simulator.read_once).to eq(nil) # 0000
        expect(simulator.read_once).to eq(nil) # 8005
        expect(simulator.read_once).to eq(nil) # 0000
        expect(simulator.read_once).to match("8101000300005e00535e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
        expect(simulator.read_once).to match("81020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
        expect(simulator.read_once).to match(/^21.#{initial_input}8003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-03
        expect(simulator.read_once).to match(nil)
        expect(simulator.read_once).to match(/^21.#{initial_input}804800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-48
        expect(simulator.read_once).to match(/^21.#{initial_input}820203480302#{procon_mac_addr.reverse}0301000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-02
        expect(simulator.read_once).to match(/^21.#{initial_input}8008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-08
        expect(simulator.read_once).to match(/^21.#{initial_input}90100060000010ffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000/) # 01-10-0060, Serial number
        expect(simulator.read_once).to match(/^21.#{initial_input}90105060000010bc114275a928ffffffffffffff000000000000000000000000000000000000000000000000000000000000000/) # Controller Color
        expect(simulator.read_once).to match(/^21.#{initial_input}8101030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-01, Bluetooth manual pairing
        expect(simulator.read_once).to match(/^21.#{initial_input}830400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-04, Trigger buttons elapsed time
        expect(simulator.read_once).to match(/^21.#{initial_input}9010806000001050fd0000c60f0f30619630f3d41454411554c7799c3336630000000000000000000000000000000000000000/) # 01-10-8060, Factory Sensor and Stick device parameters
        expect(simulator.read_once).to match(/^21..#{initial_input}901098600000100f30619630f3d41454411554c7799c3336630000000000000000000000000000000000000000000000000000/) # 01-10-9860, Factory Stick device parameters 2
        expect(simulator.read_once).to match(/^21..#{initial_input}90101080000010ffffffffffffffffffffffffffffffffffffffffffffb2a10000000000000000000000000000000000000000/) # 01-10-1080, User Analog sticks calibration
        expect(simulator.read_once).to be_nil # unkown
        expect(simulator.read_once).to match(/^21..#{initial_input}90103d60000010ba156211b87f29065bffe77e0e36569e8560ff323232ffffff00000000000000000000000000000000000000/) # 01-10-3d60, Factory configuration & calibration 2
        expect(simulator.read_once).to match(/^21..#{initial_input}90102880000010beff3e00f001004000400040fefffeff0800e73be73be73b0000000000000000000000000000000000000000/) # 01-10-2880, User 6-Axis Motion Sensor calibration
        expect(simulator.read_once).to match(/^21..#{initial_input}804000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-40
        expect(simulator.read_once).to be_nil # unkown
        expect(simulator.read_once).to match(/^21..#{initial_input}804800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-48
        expect(simulator.read_once).to match(/^21..#{initial_input}804800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-48
        expect(simulator.read_once).to match(/^21..#{initial_input}803000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000/) # 01-30
      end
    end
  end
end

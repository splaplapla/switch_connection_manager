require "spec_helper"

describe SwitchConnectionManager::Procon do
  let(:procon) { described_class.new }
  let(:initial_input) { SwitchConnectionManager::ProconSimulator::UART_INITIAL_INPUT }

  before do
    allow(procon).to receive(:find_procon_device) { MockProconDevice.new }
  end

  describe '#prepare!' do
    subject(:prepare!) { procon.prepare! }
    it 'エラーが起きない' do
      prepare!
    end
  end

  describe '#shutdown' do
    subject(:shutdown) { procon.shutdown }

    before do
      procon.prepare!
    end

    it 'エラーが起きない' do
      shutdown
    end
  end
end

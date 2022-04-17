require "spec_helper"

describe SwitchConnectionManager::ProconInternalStatus do
  let(:status) { SwitchConnectionManager::ProconInternalStatus.new }

  describe '#byte_of' do
    subject { status.byte_of(step: step).unpack("H*").first }

    context 'enable_player_light' do
      let(:step) { :enable_player_light }

      it { expect(subject).to eq("010000000000000000003001") }
    end

    context 'disable_player_light' do
      let(:step) { :disable_player_light }

      it { expect(subject).to eq("010000000000000000003000") }
    end

    context '#enable_home_button_light' do
      let(:step) { :enable_home_button_light }

      it { expect(subject).to eq("010000000000000000003801") }
    end

    context '#disable_home_button_light' do
      let(:step) { :disable_home_button_light }

      it { expect(subject).to eq("010000000000000000003800") }
    end
  end

  describe '#received?' do
    before do
      status.mark_as_send(step: step)
    end

    subject { status.received?(step: step) }

    context 'enable_player_light' do
      let(:step) { :enable_player_light }

      context 'not received' do
        it { expect(subject).to eq(false) }
      end

      context 'did receive' do
        let(:raw_data) { ["2143810080007cb878903870098030"].pack("H*") }
        before { status.receive(raw_data: raw_data) }
        it { expect(subject).to eq(true) }
      end
    end

    context 'disable_player_light' do
      let(:step) { :disable_player_light }

      context 'not received' do
        it { expect(subject).to eq(false) }
      end

      context 'did receive' do
        let(:raw_data) { ["2143810080007cb878903870098030"].pack("H*") }
        before { status.receive(raw_data: raw_data) }
        it { expect(subject).to eq(true) }
      end
    end
  end
end

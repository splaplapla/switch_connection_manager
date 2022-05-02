require "spec_helper"

describe SwitchConnectionManager::Mouse do
  describe SwitchConnectionManager::Mouse::DataParser do
    let(:raw_data) { [input.gsub(" ", "")].pack("H*") }

    describe '.parse' do
      context '' do
        let(:input) { "7d5661621677030002000000ffffffff" }
        it do
          mouse_data = SwitchConnectionManager::Mouse::DataParser.parse(raw_data)
          puts mouse_data
        end
      end

      context '' do
        let(:input) { "7d56616212fa020002000100ffffffff" }
        it do
          mouse_data = SwitchConnectionManager::Mouse::DataParser.parse(raw_data)
          puts mouse_data
        end
      end

      context '' do
        let(:input) { "7d566162120002000000000000000000" }
        it do
          mouse_data = SwitchConnectionManager::Mouse::DataParser.parse(raw_data)
          puts mouse_data
        end
      end

      context '左クリック' do
        let(:input) { "6407 6261 f7b1 000e 0001 0110 0000 0000".gsub(" ", "") }
        it do
          mouse_data = SwitchConnectionManager::Mouse::DataParser.parse(raw_data)
          puts mouse_data
        end
      end

      context '右クリック' do
        let(:input) { "646e 6261 88b8 0005 0001 0111 0001 0000" }
        it do
          mouse_data = SwitchConnectionManager::Mouse::DataParser.parse(raw_data)
          puts mouse_data
        end
      end

      context 'ホイール前進' do
        let(:input) { "64d4 6261 20cd 0000 0002 000b 0078 0000" }
        it do
          mouse_data = SwitchConnectionManager::Mouse::DataParser.parse(raw_data)
          puts mouse_data
        end
      end
    end
  end
end

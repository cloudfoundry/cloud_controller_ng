require 'spec_helper'

RSpec.describe VCAP do
  describe '.process_running?' do
    before do
      allow_message_expectations_on_nil
      `echo 'setting $? to 0'`
    end

    describe 'with an invalid pid' do
      it 'returns false with negative pid' do
        expect(VCAP.process_running?(-5)).to be_falsey
      end

      it 'returns false with nil pid' do
        expect(VCAP.process_running?(nil)).to be_falsey
      end
    end

    it 'is true with a running process' do
      expect(subject).to receive(:'`').with('ps -o rss= -p 12').and_return('some output')
      expect(VCAP.process_running?(12)).to be_truthy
    end

    it 'is false without a running process' do
      expect(subject).to receive(:'`').with('ps -o rss= -p 12').and_return('')
      expect(VCAP.process_running?(12)).to be_falsey
    end
  end
end

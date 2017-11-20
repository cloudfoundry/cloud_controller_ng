require 'spec_helper'

RSpec.describe VCAP do
  describe '.process_running?' do
    before do
      allow_message_expectations_on_nil
    end

    describe 'invalid pid' do
      it 'should return false with negative pid' do
        expect(VCAP.process_running?(-5)).to be_falsey
      end
      it 'should return false with nil pid' do
        expect(VCAP.process_running?(nil)).to be_falsey
      end
    end

    describe 'in a unix environment' do
      before do
        stub_const('VCAP::WINDOWS', false)
        `echo 'setting $? to 0'`
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

    describe 'in a windows environment' do
      before do
        stub_const('VCAP::WINDOWS', true)
        `echo 'setting $? to 0'`
      end

      it 'is true with a running process' do
        expect(subject).to receive(:'`').with('tasklist /nh /fo csv /fi "pid eq 12"').and_return('some output')
        expect(VCAP.process_running?(12)).to be_truthy
      end

      it 'is false without a running process' do
        expect(subject).to receive(:'`').with('tasklist /nh /fo csv /fi "pid eq 12"').and_return('')
        expect(VCAP.process_running?(12)).to be_falsey
      end
    end
  end
end

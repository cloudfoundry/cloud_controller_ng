require 'spec_helper'
require 'vcap/host_system'

RSpec.describe VCAP::HostSystem do
  describe '.process_running?' do
    before do
      `echo 'setting $? to 0'`
    end

    describe 'with an invalid pid' do
      it 'returns false with negative pid' do
        expect(subject).not_to be_process_running(-5)
      end

      it 'returns false with nil pid' do
        expect(subject).not_to be_process_running(nil)
      end
    end

    it 'is true with a running process' do
      expect(subject).to receive(:`).with('ps -o rss= -p 12').and_return('some output')
      expect(subject).to be_process_running(12)
    end

    it 'is false without a running process' do
      expect(subject).to receive(:`).with('ps -o rss= -p 12').and_return('')
      expect(subject).not_to be_process_running(12)
    end
  end
end

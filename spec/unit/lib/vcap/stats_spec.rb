require 'spec_helper'

RSpec.describe VCAP::Stats do
  describe '#process_memory_bytes_and_cpu' do
    before do
      allow(VCAP::Stats).to receive_messages(ps_pid: "123456 7.8\n", ps_ppid: "121212 3.4\n343434 5.6\n")
    end

    it 'returns the memory bytes and cpu for the process' do
      rss_bytes, pcpu = VCAP::Stats.process_memory_bytes_and_cpu

      expect(rss_bytes).to eq(126_418_944)
      expect(pcpu).to eq(8)
    end

    context 'when Puma is configured as webserver' do
      before do
        TestConfig.override(webserver: 'puma')
      end

      it 'returns the summed up memory bytes and cpu for the process and its subprocesses' do
        rss_bytes, pcpu = VCAP::Stats.process_memory_bytes_and_cpu

        expect(rss_bytes).to eq(602_216_448)
        expect(pcpu).to eq(17)
      end
    end
  end
end

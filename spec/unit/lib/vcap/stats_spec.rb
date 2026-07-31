require 'spec_helper'

RSpec.describe VCAP::Stats do
  describe '#process_memory_bytes_and_cpu' do
    before do
      allow(VCAP::Stats).to receive_messages(ps_pid: "123456 7.8\n", ps_ppid: "121212 3.4\n343434 5.6\n")
    end

    it 'returns the summed up memory bytes and cpu for the process and its subprocesses' do
      rss_bytes, pcpu = VCAP::Stats.process_memory_bytes_and_cpu

      expect(rss_bytes).to eq(602_216_448)
      expect(pcpu).to eq(17)
    end
  end

  describe 'system metrics on Linux' do
    let(:meminfo) do
      <<~MEMINFO
        MemTotal:       16793990 kB
        MemFree:        10810368 kB
        MemAvailable:   13636608 kB
        Buffers:          455475 kB
        Cached:          2707660 kB
        Active:           920268 kB
        Inactive:        4609024 kB
      MEMINFO
    end
    let(:loadavg) { "1.37 1.21 1.05 2/512 12345\n" }

    before do
      allow(VCAP::Stats).to receive(:linux?).and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with('/proc/meminfo').and_return(meminfo)
      allow(File).to receive(:read).with('/proc/loadavg').and_return(loadavg)
    end

    describe '#memory_free_bytes' do
      it 'returns (Inactive + MemFree) in bytes' do
        expect(VCAP::Stats.memory_free_bytes).to eq((4_609_024 + 10_810_368) * 1024)
      end
    end

    describe '#memory_used_bytes' do
      it 'returns (MemTotal - Inactive - MemFree) in bytes' do
        expect(VCAP::Stats.memory_used_bytes).to eq((16_793_990 - 4_609_024 - 10_810_368) * 1024)
      end
    end

    describe '#cpu_load_average' do
      it 'returns the one-minute load as a float' do
        expect(VCAP::Stats.cpu_load_average).to eq(1.37)
      end
    end
  end

  describe 'system metrics on non-Linux' do
    before do
      allow(VCAP::Stats).to receive(:linux?).and_return(false)
    end

    it 'returns 0 for memory_used_bytes' do
      expect(VCAP::Stats.memory_used_bytes).to eq(0)
    end

    it 'returns 0 for memory_free_bytes' do
      expect(VCAP::Stats.memory_free_bytes).to eq(0)
    end

    it 'returns 0 for cpu_load_average' do
      expect(VCAP::Stats.cpu_load_average).to eq(0)
    end
  end
end

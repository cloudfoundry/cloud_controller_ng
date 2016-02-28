require 'spec_helper'
require 'presenters/v3/process_stats_presenter'

module VCAP::CloudController
  describe ProcessStatsPresenter do
    subject(:presenter) { described_class.new }

    describe '#present_stats_hash' do
      let(:process) { AppFactory.make }
      let(:process_usage) { process.type.usage }
      let(:stats_for_process) do
        {
          0 => {
            'state' => 'RUNNING',
            'details' => 'some-details',
            'stats' => {
              'name' => process.name,
              'uris' => process.uris,
              'host' => 'myhost',
              'port' => 8080,
              'uptime' => 12345,
              'mem_quota'  => process[:memory] * 1024 * 1024,
              'disk_quota' => process[:disk_quota] * 1024 * 1024,
              'fds_quota' => process.file_descriptors,
              'usage' => {
                'time' => '2015-12-08 16:54:48 -0800',
                'cpu'  => 80,
                'mem'  => 128,
                'disk' => 1024,
              }
            }
          },
          1 => {
            'state' => 'CRASHED',
            'stats' => {
              'name' => process.name,
              'uris' => process.uris,
              'host' => 'toast',
              'port' => 8081,
              'uptime' => 42,
              'mem_quota'  => process[:memory] * 1024 * 1024,
              'disk_quota' => process[:disk_quota] * 1024 * 1024,
              'fds_quota' => process.file_descriptors,
              'usage' => {
                'time' => '2015-03-13 16:54:48 -0800',
                'cpu'  => 70,
                'mem'  => 128,
                'disk' => 1024,
              }
            }
          }
        }
      end

      it 'presents the process stats as a hash' do
        result = presenter.present_stats_hash(process.type, stats_for_process)

        expect(result[0][:type]).to eq(process.type)
        expect(result[0][:index]).to eq(0)
        expect(result[0][:state]).to eq('RUNNING')
        expect(result[0][:host]).to eq('myhost')
        expect(result[0][:port]).to eq(8080)
        expect(result[0][:uptime]).to eq(12345)
        expect(result[0][:mem_quota]).to eq(process[:memory] * 1024 * 1024)
        expect(result[0][:disk_quota]).to eq(process[:disk_quota] * 1024 * 1024)
        expect(result[0][:fds_quota]).to eq(process.file_descriptors)
        expect(result[0][:usage]).to eq({ time: '2015-12-08 16:54:48 -0800',
                                          cpu: 80,
                                          mem: 128,
                                          disk: 1024 })
        expect(result[1][:type]).to eq(process.type)
        expect(result[1][:index]).to eq(1)
        expect(result[1][:state]).to eq('CRASHED')
        expect(result[1][:host]).to eq('toast')
        expect(result[1][:port]).to eq(8081)
        expect(result[1][:uptime]).to eq(42)
        expect(result[1][:usage]).to eq({ time: '2015-03-13 16:54:48 -0800',
                                          cpu: 70,
                                          mem: 128,
                                          disk: 1024 })
      end
    end
  end
end

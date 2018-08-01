require 'spec_helper'
require 'presenters/v3/process_stats_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ProcessStatsPresenter do
    subject(:presenter) { described_class.new(process.type, stats_for_process) }
    let(:process) { VCAP::CloudController::AppFactory.make }

    describe '#present_stats_hash' do
      let(:process_usage) { process.type.usage }
      let(:net_info_1) {
        {
          address: '1.2.3.4',
          ports: [
            {
              host_port: 8080,
              container_port: 1234
            }, {
              host_port: 3000,
              container_port: 4000
            }
          ]
        }
      }

      let(:net_info_2) {
        {
          address: '',
          ports: nil
        }
      }

      let(:instance_ports_1) {
        [
          {
            external: 8080,
            internal: 1234
          }, {
            external: 3000,
            internal: 4000
          }
        ]
      }

      let(:instance_ports_2) { [] }

      let(:stats_for_process) do
        {
          0 => {
            state: 'RUNNING',
            details: 'some-details',
            stats: {
              name: process.name,
              uris: process.uris,
              host: 'myhost',
              net_info: net_info_1,
              uptime: 12345,
              mem_quota:  process[:memory] * 1024 * 1024,
              disk_quota: process[:disk_quota] * 1024 * 1024,
              fds_quota: process.file_descriptors,
              usage: {
                time: '2015-12-08 16:54:48 -0800',
                cpu:  80,
                mem:  128,
                disk: 1024,
              }
            }
          },
          1 => {
            state: 'CRASHED',
            stats: {
              name: process.name,
              uris: process.uris,
              host: 'toast',
              net_info: net_info_2,
              uptime: 42,
              mem_quota:  process[:memory] * 1024 * 1024,
              disk_quota: process[:disk_quota] * 1024 * 1024,
              fds_quota: process.file_descriptors,
              usage: {
                time: '2015-03-13 16:54:48 -0800',
                cpu:  70,
                mem:  128,
                disk: 1024,
              }
            }
          },
          2 => {
            state: 'DOWN',
            uptime: 0,
          }
        }
      end

      it 'presents the process stats as a hash' do
        result = presenter.present_stats_hash

        expect(result[0][:type]).to eq(process.type)
        expect(result[0][:index]).to eq(0)
        expect(result[0][:state]).to eq('RUNNING')
        expect(result[0][:host]).to eq('myhost')
        expect(result[0][:instance_ports]).to eq(instance_ports_1)
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
        expect(result[1][:instance_ports]).to eq(instance_ports_2)
        expect(result[1][:uptime]).to eq(42)
        expect(result[1][:usage]).to eq({ time: '2015-03-13 16:54:48 -0800',
                                          cpu: 70,
                                          mem: 128,
                                          disk: 1024 })

        expect(result[2]).to eq(
          type:  process.type,
          index: 2,
          state: 'DOWN',
          uptime: 0
        )
      end
    end

    describe '#to_hash' do
      let(:stats_for_process) { {} }
      it 'maps the content of #present_stats_hash to :resources' do
        allow(presenter).to receive(:present_stats_hash).and_return({ a: 1, b: 2 })
        expect(presenter.to_hash).to eq(resources: { a: 1, b: 2 })
      end
    end
  end
end

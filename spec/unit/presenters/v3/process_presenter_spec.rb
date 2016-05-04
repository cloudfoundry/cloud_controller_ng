require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController
  describe ProcessPresenter do
    describe '#to_hash' do
      let(:app_model) { AppModel.make }
      let(:process) {
        App.make(
          diego:                true,
          app_guid:             app_model.guid,
          instances:            3,
          memory:               42,
          disk_quota:           37,
          command:              'rackup',
          metadata:             {},
          health_check_type:    'process',
          health_check_timeout: 51,
          ports:                [1234, 7896],
          created_at:           Time.at(1)
        )
      }
      subject(:result) { ProcessPresenter.new(process, base_url).to_hash }
      let(:base_url) { nil }

      before do
        process.updated_at = Time.at(2)
      end

      it 'presents the process as json' do
        links = {
          self: { href: "/v3/processes/#{process.guid}" },
          scale: { href: "/v3/processes/#{process.guid}/scale", method: 'PUT' },
          app: { href: "/v3/apps/#{app_model.guid}" },
          space: { href: "/v2/spaces/#{process.space_guid}" },
          stats: { href: "/v3/processes/#{process.guid}/stats" },
        }

        expect(result[:guid]).to eq(process.guid)
        expect(result[:instances]).to eq(3)
        expect(result[:memory_in_mb]).to eq(42)
        expect(result[:disk_in_mb]).to eq(37)
        expect(result[:command]).to eq('rackup')
        expect(result[:health_check][:type]).to eq('process')
        expect(result[:health_check][:data][:timeout]).to eq(51)
        expect(result[:ports]).to match_array([1234, 7896])
        expect(result[:created_at]).to eq('1970-01-01T00:00:01Z')
        expect(result[:updated_at]).to eq('1970-01-01T00:00:02Z')
        expect(result[:links]).to eq(links)
      end

      context 'when diego thinks that a different port should be used' do
        let(:open_process_ports) { double(:app_ports, to_a: [5678]) }

        before do
          allow(VCAP::CloudController::Diego::Protocol::OpenProcessPorts).to receive(:new).with(process).and_return(open_process_ports)
        end

        it 'uses those ports' do
          expect(result[:ports]).to match_array([5678])
        end
      end

      context 'when base_url is set' do
        let(:base_url) { '/v3/monkeys' }

        it 'uses the base_url for stats' do
          expect(result[:links][:stats][:href]).to eq('/v3/monkeys/stats')
        end
      end
    end
  end
end

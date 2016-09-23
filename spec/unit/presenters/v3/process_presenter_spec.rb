require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ProcessPresenter do
    describe '#to_hash' do
      let(:app_model) { VCAP::CloudController::AppModel.make }
      let(:process) {
        VCAP::CloudController::App.make(
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
      let(:result) { ProcessPresenter.new(process).to_hash }

      let(:scheme) { TestConfig.config[:external_protocol] }
      let(:host) { TestConfig.config[:external_domain] }
      let(:link_prefix) { "#{scheme}://#{host}" }

      before do
        process.updated_at = Time.at(2)
      end

      it 'presents the process as a hash' do
        links = {
          self: { href: "#{link_prefix}/v3/processes/#{process.guid}" },
          scale: { href: "#{link_prefix}/v3/processes/#{process.guid}/scale", method: 'PUT' },
          app: { href: "#{link_prefix}/v3/apps/#{app_model.guid}" },
          space: { href: "#{link_prefix}/v2/spaces/#{process.space_guid}" },
          stats: { href: "#{link_prefix}/v3/processes/#{process.guid}/stats" },
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

      context 'when show_secrets is false' do
        let(:result) { ProcessPresenter.new(process, show_secrets: false).to_hash }

        it 'redacts command' do
          expect(result[:command]).to eq('[PRIVATE DATA HIDDEN]')
        end
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
    end
  end
end

require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController
  describe ProcessPresenter do
    describe '#present_json' do
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
      let(:json_result) { ProcessPresenter.new.present_json(process, base_url) }
      let(:base_url) { nil }
      subject(:result) { MultiJson.load(json_result) }

      before do
        process.updated_at = Time.at(2)
      end

      it 'presents the process as json' do
        links = {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{process.space_guid}" },
          'stats' => { 'href' => "/v3/processes/#{process.guid}/stats" },
        }

        expect(result['guid']).to eq(process.guid)
        expect(result['instances']).to eq(3)
        expect(result['memory_in_mb']).to eq(42)
        expect(result['disk_in_mb']).to eq(37)
        expect(result['command']).to eq('rackup')
        expect(result['health_check']['type']).to eq('process')
        expect(result['health_check']['data']['timeout']).to eq(51)
        expect(result['ports']).to match_array([1234, 7896])
        expect(result['created_at']).to eq('1970-01-01T00:00:01Z')
        expect(result['updated_at']).to eq('1970-01-01T00:00:02Z')
        expect(result['links']).to eq(links)
      end

      context 'when diego thinks that a different port should be used' do
        let(:open_process_ports) { double(:app_ports, to_a: [5678]) }

        before do
          allow(VCAP::CloudController::Diego::Protocol::OpenProcessPorts).to receive(:new).with(process).and_return(open_process_ports)
        end

        it 'uses those ports' do
          expect(result['ports']).to match_array([5678])
        end
      end

      context 'when base_url is set' do
        let(:base_url) { '/v3/monkeys' }

        it 'uses the base_url for stats' do
          expect(result['links']['stats']['href']).to eq('/v3/monkeys/stats')
        end
      end
    end

    describe '#present_json_stats' do
      let(:process) { AppFactory.make }
      let(:process_presenter) { ProcessPresenter.new }
      let(:process_usage) { process.type.usage }

      before do
        allow_any_instance_of(ProcessStatsPresenter).to receive(:present_stats_hash).
          with(process.type, :initial_stats).
          and_return(:presented_stats)
      end

      it 'presents the process stats as json' do
        json_result = process_presenter.present_json_stats(process, :initial_stats)
        result      = MultiJson.load(json_result)

        expect(result['resources']).to eq('presented_stats')
      end

      it 'does not include a pagination section' do
        json_result = process_presenter.present_json_stats(process, :initial_stats)
        result      = MultiJson.load(json_result)

        expect(result).not_to have_key('pagination')
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { double(:pagination_presenter) }
      let(:process1) { AppFactory.make }
      let(:process2) { AppFactory.make }
      let(:processes) { [process1, process2] }
      let(:presenter) { ProcessPresenter.new(pagination_presenter) }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:total_results) { 2 }
      let(:options) { { page: page, per_page: per_page } }
      let(:paginated_result) { PaginatedResult.new(processes, total_results, PaginationOptions.new(options)) }
      before do
        allow(pagination_presenter).to receive(:present_pagination_hash) do |_, url|
          "pagination-#{url}"
        end
      end

      it 'presents the processes as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result, 'potato')
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |app_json| app_json['guid'] }
        expect(guids).to eq([process1.guid, process2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result, 'bazooka')
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination-bazooka')
      end
    end
  end
end

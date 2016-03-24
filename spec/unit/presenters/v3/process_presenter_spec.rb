require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController
  describe ProcessPresenter do
    describe '#present_json' do
      it 'presents the process as json' do
        app_model = AppModel.make

        process = App.make(
          app_guid:             app_model.guid,
          instances:            3,
          memory:               42,
          disk_quota:           37,
          command:              'rackup',
          metadata:             {},
          health_check_type:    'process',
          health_check_timeout: 51,
          created_at:           Time.at(1)
        )
        process.updated_at = Time.at(2)

        json_result = ProcessPresenter.new.present_json(process)
        result      = MultiJson.load(json_result)

        links = {
          'self'  => { 'href' => "/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "/v3/processes/#{process.guid}/scale", 'method' => 'PUT' },
          'app'   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "/v2/spaces/#{process.space_guid}" },
        }

        expect(result['guid']).to eq(process.guid)
        expect(result['instances']).to eq(3)
        expect(result['memory_in_mb']).to eq(42)
        expect(result['disk_in_mb']).to eq(37)
        expect(result['command']).to eq('rackup')
        expect(result['health_check']['type']).to eq('process')
        expect(result['health_check']['data']['timeout']).to eq(51)
        expect(result['created_at']).to eq('1970-01-01T00:00:01Z')
        expect(result['updated_at']).to eq('1970-01-01T00:00:02Z')
        expect(result['links']).to eq(links)
      end
    end

    describe '#present_json_stats' do
      let(:process) { AppFactory.make }
      let(:process_presenter) { ProcessPresenter.new }
      let(:process_usage) { process.type.usage }
      let(:base_url) { '/v3/chimpanzee-driving-a-boat' }
      let(:stats_for_app) do
        {
          0 => {
            'state'   => 'RUNNING',
            'details' => 'some-details',
            'stats'   => {
              'name'       => process.name,
              'uris'       => process.uris,
              'host'       => 'myhost',
              'port'       => 8080,
              'uptime'     => 12345,
              'mem_quota'  => process[:memory] * 1024 * 1024,
              'disk_quota' => process[:disk_quota] * 1024 * 1024,
              'fds_quota'  => process.file_descriptors,
              'usage'      => {
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
              'name'       => process.name,
              'uris'       => process.uris,
              'host'       => 'toast',
              'port'       => 8081,
              'uptime'     => 42,
              'mem_quota'  => process[:memory] * 1024 * 1024,
              'disk_quota' => process[:disk_quota] * 1024 * 1024,
              'fds_quota'  => process.file_descriptors,
              'usage'      => {
                'time' => '2015-03-13 16:54:48 -0800',
                'cpu'  => 70,
                'mem'  => 128,
                'disk' => 1024,
              }
            }
          }
        }
      end

      it 'presents the process stats as json' do
        json_result = process_presenter.present_json_stats(process, stats_for_app, base_url)
        result      = MultiJson.load(json_result)

        stats = result['resources']
        expect(stats[0]['type']).to eq(process.type)
        expect(stats[0]['index']).to eq(0)
        expect(stats[0]['state']).to eq('RUNNING')
        expect(stats[0]['host']).to eq('myhost')
        expect(stats[0]['port']).to eq(8080)
        expect(stats[0]['uptime']).to eq(12345)
        expect(stats[0]['mem_quota']).to eq(process[:memory] * 1024 * 1024)
        expect(stats[0]['disk_quota']).to eq(process[:disk_quota] * 1024 * 1024)
        expect(stats[0]['fds_quota']).to eq(process.file_descriptors)
        expect(stats[0]['usage']).to eq({ 'time' => '2015-12-08 16:54:48 -0800',
                                          'cpu'                                  => 80,
                                          'mem'                                  => 128,
                                          'disk'                                 => 1024 })
        expect(stats[1]['type']).to eq(process.type)
        expect(stats[1]['index']).to eq(1)
        expect(stats[1]['state']).to eq('CRASHED')
        expect(stats[1]['host']).to eq('toast')
        expect(stats[1]['port']).to eq(8081)
        expect(stats[1]['uptime']).to eq(42)
        expect(stats[1]['usage']).to eq({ 'time' => '2015-03-13 16:54:48 -0800',
                                          'cpu'                                  => 70,
                                          'mem'                                  => 128,
                                          'disk'                                 => 1024 })
      end

      it 'includes a pagination section' do
        json_result = process_presenter.present_json_stats(process, stats_for_app, base_url)
        result      = MultiJson.load(json_result)

        expect(result).to have_key('pagination')
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

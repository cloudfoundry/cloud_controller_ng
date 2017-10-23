require 'spec_helper'
require 'benchmark'

RSpec.describe 'Processes', performance: true, isolation: :truncation do
  let!(:space) do
    VCAP::CloudController::Space.make
  end

  describe 'GET /v3/processes' do
    let(:developer) { make_developer_for_space(space) }
    let(:user_name) { 'ProcHudson' }

    before(:each) do
      2_500.times do
        app     = VCAP::CloudController::AppModel.make(space: space)
        droplet = VCAP::CloudController::DropletModel.make(app: app)
        app.update(droplet: droplet)
        2.times do
          VCAP::CloudController::ProcessModel.make(:process, app: app)
        end
      end
    end

    context 'when the user is a space developer' do
      let(:developer_headers) { headers_for(developer, user_name: user_name) }

      it 'returns results promptly' do
        3.times do
          time = Benchmark.measure { get '/v3/processes?per_page=5000', nil, developer_headers }
          expect(time.real).to be <= 11.0
        end
      end
    end

    context 'when the user is an admin' do
      let(:admin_headers) { admin_headers_for(developer, user_name: user_name) }

      it 'returns results promptly' do
        3.times do
          time = Benchmark.measure { get '/v3/processes?per_page=5000', nil, admin_headers }
          expect(time.real).to be <= 11.0
        end
      end
    end
  end
end

require 'spec_helper'
require 'rails_helper'

RSpec.describe PackagesController, type: :controller do # , isolation: :truncation
  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:space1) { VCAP::CloudController::Space.make }
    let(:space2) { VCAP::CloudController::Space.make }
    let(:space3) { VCAP::CloudController::Space.make }
    let(:user_spaces) { [space, space1, space2, space3] }
    let!(:user_package_1) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:user_package_2) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:admin_package) { VCAP::CloudController::PackageModel.make }

    let(:n) { 10 }

    before do
      TestConfig.override({
        db: {
          log_level: 'debug',
      }
        # logging.level: 'debug2'
      })
      allow_user_read_access_for(user, spaces: user_spaces)
      n.times do |i|
        app = VCAP::CloudController::AppModel.make(space: user_spaces.sample, guid: "app-guid-#{i}")
        3.times do |j|
          VCAP::CloudController::PackageModel.make(app_guid: app.guid, guid: "package-guid-#{i}-#{j}")
        end
      end
    end

    it 'uses the app and pagination as query parameters' do
      runs = 10

      search_time = 0
      runs.times do |i|
        app_guid_num = rand(n)
        app = VCAP::CloudController::AppModel.find(guid: "app-guid-#{app_guid_num}")

        start_time = Time.now
        get :index, params: { app_guids: app.guid, page: 1, per_page: 10, states: 'AWAITING_UPLOAD' }
        end_time = Time.now
        search_time += end_time - start_time
      end

      avg_time = (search_time * 1.0) / runs

      expect(response.status).to eq(200)
      expect(parsed_body['resources'].size).to be(3)

      expect(avg_time).to be <= 0.2
    end
  end
end

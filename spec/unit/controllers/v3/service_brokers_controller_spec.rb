require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe ServiceBrokersController, type: :controller do
  describe '#create' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:space) { VCAP::CloudController::Space.make }

    let(:request_body) do
      {
        name: 'some-name',
        relationships: { space: { data: { guid: space_guid } } },
        url: 'https://fake.url',
        credentials: {
          type: 'basic',
          data: {
            username: 'fake username',
            password: 'fake password',
          },
        },
      }
    end

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
    end

    context 'when a non-existent space is provided' do
      let(:space_guid) { 'space-that-does-not-exist' }

      it 'returns a error saying the space is invalid' do
        post :create, params: request_body, as: :json

        expect(response).to have_status_code(422)
        expect(response.body).to include 'Invalid space. Ensure that the space exists and you have access to it.'
      end
    end

    context 'when a space is provided that the user cannot read' do
      let(:space_with_no_read_access) { VCAP::CloudController::Space.make }
      let(:space_guid) { space_with_no_read_access.guid }

      it 'returns a error saying the space is invalid' do
        post :create, params: request_body, as: :json

        expect(response).to have_status_code(422)
        expect(response.body).to include 'Invalid space. Ensure that the space exists and you have access to it.'
      end
    end
  end
end

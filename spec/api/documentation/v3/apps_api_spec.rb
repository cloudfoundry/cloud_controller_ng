require 'spec_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Apps (Experimental)', type: :api do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status == 500
      error = MultiJson.dump(response_body)
      ap error
      raise error['description']
    end
  end

  get '/v3/apps/:guid' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:guid) { app_model.guid }

    example 'Get an App' do
      expected_response = {
        'guid'   => guid,
        '_links' => {
          'self'      => { 'href' => "/v3/apps/#{guid}" },
          'processes' => { 'href' => "/v3/apps/#{guid}/processes" }
        }
      }

      do_request_with_error_handling

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end
end

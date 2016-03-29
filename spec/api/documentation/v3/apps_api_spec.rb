require 'rails_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Apps (Experimental)', type: :api do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status > 299
      error = MultiJson.load(response_body)
      ap error
      raise error['description']
    end
  end

  put '/v3/apps/:guid/current_droplet' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:process_types) { { web: 'start the app' } }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid, process_types: process_types, state: VCAP::CloudController::DropletModel::STAGED_STATE) }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'name1', space_guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model)
    end

    body_parameter :droplet_guid, 'GUID of the Staged Droplet to be used for the App'

    let(:droplet_guid) { droplet.guid }
    let(:guid) { app_model.guid }

    let(:raw_post) { body_parameters }
    header 'Content-Type', 'application/json'

    example 'Assigning a droplet as an App\'s current droplet' do
      do_request_with_error_handling

      expected_response = {
        'name'                    => app_model.name,
        'guid'                    => app_model.guid,
        'desired_state'           => app_model.desired_state,
        'total_desired_instances' => 1,
        'environment_variables'   => {},
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => app_model.lifecycle_data.buildpack,
            'stack'     => app_model.lifecycle_data.stack,
          }
        },
        'links' => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplet'                => { 'href' => "/v3/droplets/#{droplet_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
      event = VCAP::CloudController::Event.where(actor: user.guid).first
      expect(event.values).to include({
            type:              'audit.app.droplet_mapped',
            actee:             app_model.guid,
            actee_type:        'v3-app',
            actee_name:        app_model.name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid
          })
      expect(event.metadata).to eq({ 'request' => { 'droplet_guid' => droplet.guid } })
      expect(app_model.reload.processes).not_to be_empty
    end
  end
end

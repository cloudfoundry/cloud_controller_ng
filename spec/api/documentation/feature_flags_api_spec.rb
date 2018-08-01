require 'spec_helper'
require 'rspec_api_documentation/dsl'

# rubocop:disable Metrics/LineLength
RSpec.resource 'Feature Flags', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }

  authenticated_request

  shared_context 'name_parameter' do
    parameter :name, 'The name of the feature flag',
      valid_values: ['user_org_creation', 'app_bits_upload', 'private_domain_creation', 'app_scaling',
                     'route_creation', 'service_instance_creation', 'diego_docker', 'set_roles_by_username',
                     'unset_roles_by_username', 'task_creation (experimental)',
                     'space_scoped_private_broker_creation (experimental)',
                     'space_developer_env_var_visibility (experimental)']
  end

  shared_context 'updatable_fields' do
    field :enabled, 'The state of the feature flag.', required: true, valid_values: [true, false]
    field :error_message, 'The custom error message for the feature flag.', example_values: ['error message']
  end

  get '/v2/config/feature_flags' do
    example 'Get all feature flags' do
      VCAP::CloudController::FeatureFlag.create(name: 'private_domain_creation', enabled: false, error_message: 'foobar')

      client.get '/v2/config/feature_flags', {}, headers

      expect(status).to eq(200)
      expect(parsed_response.length).to eq(13)
      expect(parsed_response).to include(
        {
          'name'          => 'user_org_creation',
          'enabled'       => false,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/user_org_creation'
        })
      expect(parsed_response).to include(
        {
          'name'          => 'app_bits_upload',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/app_bits_upload'
        })
      expect(parsed_response).to include(
        {
          'name'          => 'app_scaling',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/app_scaling'
        })
      expect(parsed_response).to include(
        {
          'name'          => 'private_domain_creation',
          'enabled'       => false,
          'error_message' => 'foobar',
          'url'           => '/v2/config/feature_flags/private_domain_creation'
        })
      expect(parsed_response).to include(
        {
          'name'          => 'route_creation',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/route_creation'
        })
      expect(parsed_response).to include(
        {
          'name'          => 'service_instance_creation',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/service_instance_creation'
        })
      expect(parsed_response).to include(
        {
            'name' => 'set_roles_by_username',
            'enabled' => true,
            'error_message' => nil,
            'url' => '/v2/config/feature_flags/set_roles_by_username'
        })
      expect(parsed_response).to include(
        {
            'name' => 'unset_roles_by_username',
            'enabled' => true,
            'error_message' => nil,
            'url' => '/v2/config/feature_flags/unset_roles_by_username'
        })
      expect(parsed_response).to include(
        {
            'name' => 'diego_docker',
            'enabled' => false,
            'error_message' => nil,
            'url' => '/v2/config/feature_flags/diego_docker'
        })
      expect(parsed_response).to include(
        {
            'name' => 'task_creation',
            'enabled' => false,
            'error_message' => nil,
            'url' => '/v2/config/feature_flags/task_creation'
        })
      expect(parsed_response).to include(
        {
            'name' => 'space_scoped_private_broker_creation',
            'enabled' => true,
            'error_message' => nil,
            'url' => '/v2/config/feature_flags/space_scoped_private_broker_creation'
        })
      expect(parsed_response).to include(
        {
            'name' => 'space_developer_env_var_visibility',
            'enabled' => true,
            'error_message' => nil,
            'url' => '/v2/config/feature_flags/space_developer_env_var_visibility'
        })
      expect(parsed_response).to include(
        {
           'name' => 'env_var_visibility',
           'enabled' => true,
           'error_message' => nil,
           'url' => '/v2/config/feature_flags/env_var_visibility'
        })
    end
  end

  get '/v2/config/feature_flags/unset_roles_by_username' do
    example 'Get the Unset User Roles feature flag' do
      explanation <<-HEREDOC
        When enabled, Org Managers or Space Managers can remove access roles by username.
        In order for this feature to be enabled the CF operator must:
          1) Enable the `/ids/users/` endpoint for UAA
          2) Create a UAA `cloud_controller_username_lookup` client with the `scim.userids`
             authority
      HEREDOC

      client.get '/v2/config/feature_flags/unset_roles_by_username', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'unset_roles_by_username',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/unset_roles_by_username'
        })
    end
  end

  get '/v2/config/feature_flags/set_roles_by_username' do
    example 'Get the Set User Roles feature flag' do
      explanation <<-HEREDOC
        When enabled, Org Managers or Space Managers can add access roles by username.
        In order for this feature to be enabled the CF operator must:
          1) Enable the `/ids/users/` endpoint for UAA
          2) Create a UAA `cloud_controller_username_lookup` client with the `scim.userids`
             authority
      HEREDOC
      client.get '/v2/config/feature_flags/set_roles_by_username', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'set_roles_by_username',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/set_roles_by_username'
        })
    end
  end

  get '/v2/config/feature_flags/app_bits_upload' do
    example 'Get the App Bits Upload feature flag' do
      explanation 'When enabled, space developers can upload app bits. When disabled, only admin users can upload app bits'
      client.get '/v2/config/feature_flags/app_bits_upload', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'app_bits_upload',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/app_bits_upload'
        })
    end
  end

  get '/v2/config/feature_flags/app_scaling' do
    example 'Get the App Scaling feature flag' do
      explanation 'When enabled, space developers can perform scaling operations (i.e. change memory, disk or instances). When disabled, only admins can perform scaling operations.'
      client.get '/v2/config/feature_flags/app_scaling', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'app_scaling',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/app_scaling'
        })
    end
  end

  get '/v2/config/feature_flags/user_org_creation' do
    example 'Get the User Org Creation feature flag' do
      explanation 'When enabled, any user can create an organization via the API. When disabled, only admin users can create organizations via the API.'
      client.get '/v2/config/feature_flags/user_org_creation', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'user_org_creation',
          'enabled'       => false,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/user_org_creation'
        })
    end
  end

  get '/v2/config/feature_flags/private_domain_creation' do
    example 'Get the Private Domain Creation feature flag' do
      explanation 'When enabled, an organization manager can create private domains for that organization. When disabled, only admin users can create private domains.'
      client.get '/v2/config/feature_flags/private_domain_creation', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'private_domain_creation',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/private_domain_creation'
        })
    end
  end

  get '/v2/config/feature_flags/route_creation' do
    example 'Get the Route Creation feature flag' do
      explanation 'When enabled, a space developer can create routes in a space. When disabled, only admin users can create routes.'
      client.get '/v2/config/feature_flags/route_creation', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'route_creation',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/route_creation'
        })
    end
  end

  get '/v2/config/feature_flags/service_instance_creation' do
    example 'Get the Service Instance Creation feature flag' do
      explanation 'When enabled, a space developer can create service instances in a space. When disabled, only admin users can create service instances.'
      client.get '/v2/config/feature_flags/service_instance_creation', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'service_instance_creation',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/service_instance_creation'
        })
    end
  end

  get '/v2/config/feature_flags/diego_docker' do
    example 'Get the Diego Docker feature flag' do
      explanation 'When enabled, Docker applications are supported by Diego. When disabled, Docker applications will stop running.
                   It will still be possible to stop and delete them and update their configurations.'
      client.get '/v2/config/feature_flags/diego_docker', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'diego_docker',
          'enabled'       => false,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/diego_docker'
        })
    end
  end

  get '/v2/config/feature_flags/task_creation' do
    example 'Get the Task Creation feature flag (experimental)' do
      explanation 'When enabled, space developers can create tasks. When disabled, only admin users can create tasks.'
      client.get '/v2/config/feature_flags/task_creation', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'task_creation',
          'enabled'       => false,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/task_creation'
        })
    end
  end

  get '/v2/config/feature_flags/space_scoped_private_broker_creation' do
    example 'Get the Space Scoped Private Broker Creation feature flag (experimental)' do
      explanation 'When enabled, space developers can create space scoped private brokers.
                   When disabled, only admin users can create create space scoped private brokers.'
      client.get '/v2/config/feature_flags/space_scoped_private_broker_creation', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'space_scoped_private_broker_creation',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/space_scoped_private_broker_creation'
        })
    end
  end

  get '/v2/config/feature_flags/space_developer_env_var_visibility' do
    example 'Get the Space Developer Environment Variable Visibility feature flag (experimental)' do
      explanation 'When enabled, space developers can do a get on the /v2/apps/:guid/env and /v3/apps/:guid/env end points.
                   When disabled, space developers can no longer do a get against these end points.'
      client.get '/v2/config/feature_flags/space_developer_env_var_visibility', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'space_developer_env_var_visibility',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/space_developer_env_var_visibility'
        })
    end
  end

  get '/v2/config/feature_flags/env_var_visibility' do
    example 'Get the Environment Variable Visibility feature flag' do
      explanation 'When enabled, all users can read environment variables.
                   When disabled, only admin can read environment variables.'
      client.get '/v2/config/feature_flags/env_var_visibility', {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'env_var_visibility',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/env_var_visibility'
        })
    end
  end

  put '/v2/config/feature_flags/:name' do
    include_context 'name_parameter'
    include_context 'updatable_fields'

    example 'Set a feature flag' do
      client.put '/v2/config/feature_flags/user_org_creation', fields_json, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'user_org_creation',
          'enabled'       => true,
          'error_message' => nil,
          'url'           => '/v2/config/feature_flags/user_org_creation'
        })
    end
  end
end
# rubocop:enable Metrics/LineLength

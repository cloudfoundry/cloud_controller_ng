require 'spec_helper'

RSpec.describe 'v3 root' do
  describe 'GET /v3' do
    it 'returns a list of links to resources available on the v3 API' do
      get '/v3'
      expect(last_response).to have_status_code(200)
      expect(parsed_response).to be_a_response_like({
        'links' => {
          'self' => {
            'href' => "#{link_prefix}/v3"
          },
          'app_usage_events' => {
            'href' => "#{link_prefix}/v3/app_usage_events"
          },
          'apps' => {
            'href' => "#{link_prefix}/v3/apps"
          },
          'audit_events' => {
            'href' => "#{link_prefix}/v3/audit_events"
          },
          'buildpacks' => {
            'href' => "#{link_prefix}/v3/buildpacks"
          },
          'builds' => {
            'href' => "#{link_prefix}/v3/builds"
          },
          'deployments' => {
            'href' => "#{link_prefix}/v3/deployments"
          },
          'domains' => {
            'href' => "#{link_prefix}/v3/domains"
          },
          'droplets' => {
            'href' => "#{link_prefix}/v3/droplets"
          },
          'environment_variable_groups' => {
            'href' => "#{link_prefix}/v3/environment_variable_groups"
          },
          'feature_flags' => {
            'href' => "#{link_prefix}/v3/feature_flags",
          },
          'info' => {
            'href' => "#{link_prefix}/v3/info"
          },
          'isolation_segments' => {
            'href' => "#{link_prefix}/v3/isolation_segments"
          },
          'organizations' => {
            'href' => "#{link_prefix}/v3/organizations"
          },
          'organization_quotas' => {
            'href' => "#{link_prefix}/v3/organization_quotas"
          },
          'packages' => {
            'href' => "#{link_prefix}/v3/packages"
          },
          'processes' => {
            'href' => "#{link_prefix}/v3/processes"
          },
          'resource_matches' => {
            'href' => "#{link_prefix}/v3/resource_matches"
          },
          'roles' => {
            'href' => "#{link_prefix}/v3/roles"
          },
          'routes' => {
            'href' => "#{link_prefix}/v3/routes",
          },
          'security_groups' => {
            'href' => "#{link_prefix}/v3/security_groups"
          },
          'service_brokers' => {
            'href' => "#{link_prefix}/v3/service_brokers"
          },
          'service_instances' => {
            'href' => "#{link_prefix}/v3/service_instances"
          },
          'service_credential_bindings' => {
            'href' => "#{link_prefix}/v3/service_credential_bindings"
          },
          'service_offerings' => {
            'href' => "#{link_prefix}/v3/service_offerings"
          },
          'service_plans' => {
            'href' => "#{link_prefix}/v3/service_plans"
          },
          'service_route_bindings' => {
            'href' => "#{link_prefix}/v3/service_route_bindings"
          },
          'service_usage_events' => {
            'href' => "#{link_prefix}/v3/service_usage_events"
          },
          'spaces' => {
            'href' => "#{link_prefix}/v3/spaces"
          },
          'space_quotas' => {
            'href' => "#{link_prefix}/v3/space_quotas"
          },
          'stacks' => {
            'href' => "#{link_prefix}/v3/stacks"
          },
          'tasks' => {
            'href' => "#{link_prefix}/v3/tasks"
          },
          'users' => {
            'href' => "#{link_prefix}/v3/users"
          }
        }
      })
    end
  end
end

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
            'href' => "#{link_prefix}/v3/deployments",
            'experimental' => true
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
            'href' => "#{link_prefix}/v3/organization_quotas",
            'experimental' => true
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
          'service_brokers' => {
            'href' => "#{link_prefix}/v3/service_brokers",
            'experimental' => true
          },
          'service_instances' => {
            'href' => "#{link_prefix}/v3/service_instances"
          },
          'service_offerings' => {
            'href' => "#{link_prefix}/v3/service_offerings",
            'experimental' => true
          },
          'service_plans' => {
            'href' => "#{link_prefix}/v3/service_plans",
            'experimental' => true
          },
          'spaces' => {
            'href' => "#{link_prefix}/v3/spaces"
          },
          'space_quotas' => {
            'href' => "#{link_prefix}/v3/space_quotas",
            'experimental' => true
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

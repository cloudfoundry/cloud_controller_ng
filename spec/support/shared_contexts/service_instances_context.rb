require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.shared_context 'service instances setup' do
  let(:user) { VCAP::CloudController::User.make }
  let(:org) { VCAP::CloudController::Organization.make(created_at: Time.now.utc - 1.second) }
  let!(:org_annotation) { VCAP::CloudController::OrganizationAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'foo', value: 'bar', resource_guid: org.guid) }
  let(:space) { VCAP::CloudController::Space.make(organization: org, created_at: Time.now.utc - 1.second) }
  let!(:space_annotation) { VCAP::CloudController::SpaceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'baz', value: 'wow', space: space) }
  let(:another_space) { VCAP::CloudController::Space.make }
  let(:parameters_mixed_data_types_as_json_string) do
    '{"boolean":true,"string":"a string","int":123,"float":3.14159,"optional":null,"object":{"a":"b"},"array":["c","d"]}'
  end
  let(:parameters_mixed_data_types_as_hash) do
    {
      boolean: true,
      string: 'a string',
      int: 123,
      float: 3.14159,
      optional: nil,
      object: { a: 'b' },
      array: %w[c d]
    }
  end

  def create_managed_json(instance, labels: {}, annotations: {}, last_operation: {}, tags: [])
    {
      guid: instance.guid,
      name: instance.name,
      created_at: iso8601,
      updated_at: iso8601,
      type: 'managed',
      dashboard_url: nil,
      last_operation: last_operation,
      maintenance_info: {},
      upgrade_available: false,
      tags: tags,
      metadata: {
        labels:,
        annotations:
      },
      relationships: {
        space: {
          data: {
            guid: instance.space.guid
          }
        },
        service_plan: {
          data: {
            guid: instance.service_plan.guid
          }
        }
      },
      links: {
        self: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}"
        },
        space: {
          href: "#{link_prefix}/v3/spaces/#{instance.space.guid}"
        },
        service_plan: {
          href: "#{link_prefix}/v3/service_plans/#{instance.service_plan.guid}"
        },
        parameters: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}/parameters"
        },
        service_credential_bindings: {
          href: "#{link_prefix}/v3/service_credential_bindings?service_instance_guids=#{instance.guid}"
        },
        service_route_bindings: {
          href: "#{link_prefix}/v3/service_route_bindings?service_instance_guids=#{instance.guid}"
        },
        shared_spaces: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces"
        }
      }
    }
  end

  def create_user_provided_json(instance, labels: {}, annotations: {}, last_operation: {})
    {
      guid: instance.guid,
      name: instance.name,
      created_at: iso8601,
      updated_at: iso8601,
      type: 'user-provided',
      last_operation: last_operation,
      syslog_drain_url: instance.syslog_drain_url,
      route_service_url: instance.route_service_url,
      tags: instance.tags,
      metadata: {
        labels:,
        annotations:
      },
      relationships: {
        space: {
          data: {
            guid: instance.space.guid
          }
        }
      },
      links: {
        self: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}"
        },
        space: {
          href: "#{link_prefix}/v3/spaces/#{instance.space.guid}"
        },
        credentials: {
          href: "#{link_prefix}/v3/service_instances/#{instance.guid}/credentials"
        },
        service_credential_bindings: {
          href: "#{link_prefix}/v3/service_credential_bindings?service_instance_guids=#{instance.guid}"
        },
        service_route_bindings: {
          href: "#{link_prefix}/v3/service_route_bindings?service_instance_guids=#{instance.guid}"
        }
      }
    }
  end

  def share_service_instance(instance, target_space)
    enable_sharing!

    share_request = {
      'data' => [
        { 'guid' => target_space.guid }
      ]
    }

    post "/v3/service_instances/#{instance.guid}/relationships/shared_spaces", share_request.to_json, admin_headers
    expect(last_response.status).to eq(200)
  end

  def enable_sharing!
    VCAP::CloudController::FeatureFlag.
      find_or_create(name: 'service_instance_sharing') { |ff| ff.enabled = true }.
      update(enabled: true)
  end
end

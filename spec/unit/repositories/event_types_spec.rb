require 'spec_helper'
require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    RSpec.describe EventTypes do
      describe '#get' do
        it 'returns a valid audit event' do
          event = EventTypes.get('APP_CREATE')
          expect(event).to eq('audit.app.create')
        end

        it 'converts lower case input values' do
          event = EventTypes.get('ApP_creaTE')
          expect(event).to eq('audit.app.create')
        end

        it 'raises an error for unknown events' do
          expect { EventTypes.get('unknown_event') }.to raise_error(EventTypes::EventTypesError)
        end
      end

      describe 'all event types' do
        let(:expected_event_types) do
          ['audit.app.create',
           'audit.app.update',
           'audit.app.delete-request',
           'audit.app.start',
           'audit.app.restart',
           'audit.app.restage',
           'audit.app.stop',
           'audit.app.package.create',
           'audit.app.package.upload',
           'audit.app.package.download',
           'audit.app.package.delete',
           'audit.app.process.create',
           'audit.app.process.update',
           'audit.app.process.delete',
           'audit.app.process.ready',
           'audit.app.process.not-ready',
           'audit.app.process.rescheduling',
           'audit.app.process.crash',
           'audit.app.process.terminate_instance',
           'audit.app.process.scale',
           'audit.app.droplet.create',
           'audit.app.droplet.upload',
           'audit.app.droplet.download',
           'audit.app.droplet.delete',
           'audit.app.droplet.mapped',
           'audit.app.task.create',
           'audit.app.task.cancel',
           'audit.app.map-route',
           'audit.app.unmap-route',
           'audit.app.build.create',
           'audit.app.build.staged',
           'audit.app.build.failed',
           'audit.app.environment.show',
           'audit.app.environment_variables.show',
           'audit.app.revision.create',
           'audit.app.revision.environment_variables.show',
           'audit.app.deployment.cancel',
           'audit.app.deployment.create',
           'audit.app.deployment.continue',
           'audit.app.copy-bits',
           'audit.app.upload-bits',
           'audit.app.apply_manifest',
           'audit.app.ssh-authorized',
           'audit.app.ssh-unauthorized',
           'audit.buildpack.create',
           'audit.buildpack.update',
           'audit.buildpack.delete',
           'audit.buildpack.upload',
           'audit.service.create',
           'audit.service.update',
           'audit.service.delete',
           'audit.service_broker.create',
           'audit.service_broker.update',
           'audit.service_broker.delete',
           'audit.service_plan.create',
           'audit.service_plan.update',
           'audit.service_plan.delete',
           'audit.service_instance.create',
           'audit.service_instance.update',
           'audit.service_instance.delete',
           'audit.service_instance.start_create',
           'audit.service_instance.start_update',
           'audit.service_instance.start_delete',
           'audit.service_instance.bind_route',
           'audit.service_instance.unbind_route',
           'audit.service_instance.share',
           'audit.service_instance.unshare',
           'audit.service_instance.purge',
           'audit.service_instance.show',
           'audit.service_binding.create',
           'audit.service_binding.update',
           'audit.service_binding.delete',
           'audit.service_binding.start_create',
           'audit.service_binding.start_delete',
           'audit.service_binding.show',
           'audit.service_key.create',
           'audit.service_key.update',
           'audit.service_key.delete',
           'audit.service_key.start_create',
           'audit.service_key.start_delete',
           'audit.service_key.show',
           'audit.service_plan_visibility.create',
           'audit.service_plan_visibility.update',
           'audit.service_plan_visibility.delete',
           'audit.service_route_binding.create',
           'audit.service_route_binding.update',
           'audit.service_route_binding.delete',
           'audit.service_route_binding.start_create',
           'audit.service_route_binding.start_delete',
           'audit.user_provided_service_instance.create',
           'audit.user_provided_service_instance.update',
           'audit.user_provided_service_instance.delete',
           'audit.user_provided_service_instance.show',
           'audit.route.create',
           'audit.route.update',
           'audit.route.delete-request',
           'audit.route.share',
           'audit.route.unshare',
           'audit.route.transfer-owner',
           'audit.organization.create',
           'audit.organization.update',
           'audit.organization.delete-request',
           'audit.organization_quota.create',
           'audit.organization_quota.update',
           'audit.organization_quota.delete',
           'audit.organization_quota.apply',
           'audit.space.create',
           'audit.space.update',
           'audit.space.delete-request',
           'audit.space_quota.create',
           'audit.space_quota.update',
           'audit.space_quota.delete',
           'audit.space_quota.apply',
           'audit.space_quota.remove',
           'audit.stack.create',
           'audit.stack.update',
           'audit.stack.delete',
           'audit.user.space_auditor_add',
           'audit.user.space_auditor_remove',
           'audit.user.space_supporter_add',
           'audit.user.space_supporter_remove',
           'audit.user.space_developer_add',
           'audit.user.space_developer_remove',
           'audit.user.space_manager_add',
           'audit.user.space_manager_remove',
           'audit.service_dashboard_client.create',
           'audit.service_dashboard_client.delete',
           'audit.user.organization_user_add',
           'audit.user.organization_user_remove',
           'audit.user.organization_auditor_add',
           'audit.user.organization_auditor_remove',
           'audit.user.organization_billing_manager_add',
           'audit.user.organization_billing_manager_remove',
           'audit.user.organization_manager_add',
           'audit.user.organization_manager_remove',
           'app.crash',
           'blob.remove_orphan']
        end

        it 'expects that audit events did not change' do
          # All audit events should be correctly documented in:
          # - API docs (docs/v3/source/includes/resources/audit_events/_header.md.erb)
          # - cf docs (https://docs.cloudfoundry.org/running/managing-cf/audit-events.html)
          #
          # List of all events can be obtained with `rake docs:audit_events_list`

          expect(EventTypes::ALL_EVENT_TYPES.flatten).to match_array(expected_event_types), 'Audit events changed, adjust documentation and test'
        end
      end
    end
  end
end

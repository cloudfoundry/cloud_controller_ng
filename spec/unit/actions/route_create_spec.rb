require 'spec_helper'
require 'actions/route_create'
require 'messages/route_create_message'

module VCAP::CloudController
  RSpec.describe RouteCreate do
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'amelia@cats.com', user_guid: 'gooid') }

    subject { RouteCreate.new(user_audit_info) }

    describe '#create' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:org) { space.organization }
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

      context 'when successful' do
        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
        end

        it 'creates a route' do
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to change { Route.count }.by(1)

          route = Route.last
          expect(route.space.guid).to eq space.guid
          expect(route.domain.guid).to eq domain.guid
        end

        it 'creates an audit event' do
          expect_any_instance_of(Repositories::RouteEventRepository).
            to receive(:record_route_create).with(instance_of(Route),
              user_audit_info,
              message.audit_hash,
              manifest_triggered: false
            )

          subject.create(message: message, space: space, domain: domain)
        end
      end

      context 'when the domain has an owning org that is different from the space\'s parent org' do
        let(:other_org) { VCAP::CloudController::Organization.make }
        let(:inaccessible_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: other_org) }

        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: inaccessible_domain.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space, domain: inaccessible_domain)
          }.to raise_error(RouteCreate::Error, "Invalid domain. Domain '#{inaccessible_domain.name}' is not available in organization '#{space.organization.name}'.")
        end
      end

      context 'when the domain already has a route' do
        let!(:existing_route) { VCAP::CloudController::Route.make(host: '', space: space, domain: domain) }

        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, "Route already exists for domain '#{domain.name}'.")
        end
      end

      context 'when the space quota for routes is maxed out' do
        let!(:space_quota_definition) { SpaceQuotaDefinition.make(total_routes: 0, organization: org) }
        let!(:space_with_quota) do
          Space.make(space_quota_definition: space_quota_definition,
                     organization: org)
        end

        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space_with_quota.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space_with_quota, domain: domain)
          }.to raise_error(RouteCreate::Error, "Routes quota exceeded for space '#{space_with_quota.name}'.")
        end
      end

      context 'when the org quota for routes is maxed out' do
        let!(:org_quota_definition) { QuotaDefinition.make(total_routes: 0, total_reserved_route_ports: 0) }
        let!(:org_with_quota) { Organization.make(quota_definition: org_quota_definition) }
        let!(:space_in_org_with_quota) do
          Space.make(organization: org_with_quota)
        end
        let(:domain_in_org_with_quota) { Domain.make(owning_organization: org_with_quota) }

        let(:message) do
          RouteCreateMessage.new({
            relationships: {
              space: {
                data: { guid: space_in_org_with_quota.guid }
              },
              domain: {
                data: { guid: domain_in_org_with_quota.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space_in_org_with_quota, domain: domain_in_org_with_quota)
          }.to raise_error(RouteCreate::Error, "Routes quota exceeded for organization '#{org_with_quota.name}'.")
        end
      end

      context 'when the FQDN is too long' do
        let(:domain_with_long_name) { Domain.make(owning_organization: org, name: "#{'a' * 60}.#{'b' * 60}.#{'c' * 60}.#{'d' * 60}.com") }

        let(:message) do
          RouteCreateMessage.new({
            host: 'h' * 60,
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain_with_long_name.guid }
              },
            },
          })
        end

        it 'raises an error with a helpful message' do
          expect {
            subject.create(message: message, space: space, domain: domain_with_long_name)
          }.to raise_error(RouteCreate::Error, 'Host combined with domain name must be no more than 253 characters.')
        end
      end

      context 'when the domain is unscoped' do
        let(:shared_domain) { SharedDomain.make }

        it 'requires host not to be empty' do
          message = RouteCreateMessage.new({
            host: '',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: shared_domain.guid }
              },
            },
          })

          expect {
            subject.create(message: message, space: space, domain: shared_domain)
          }.to raise_error(RouteCreate::Error, 'Missing host. Routes in shared domains must have a host defined.')
        end
      end

      context 'when a path is invalid' do
        it 'raises an error with a helpful message' do
          message = RouteCreateMessage.new({
            host: '',
            path: '/\/\invalid-path',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, 'Path is invalid.')
        end
      end

      context 'when a path is a single /' do
        it 'raises an error with a helpful message' do
          message = RouteCreateMessage.new({
            host: '',
            path: '/',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, "Path cannot be a single '/'.")
        end
      end

      context 'when a path is missing a beginning slash' do
        it 'raises an error with a helpful message' do
          message = RouteCreateMessage.new({
            host: '',
            path: 'whereistheslash',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, "Path is missing the beginning '/'.")
        end
      end

      context 'when a path is too long' do
        it 'raises an error with a helpful message' do
          message = RouteCreateMessage.new({
            host: '',
            path: '/pathtoolong' * 5000,
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, 'Path exceeds 128 characters.')
        end
      end

      context 'when a path contains a ?' do
        it 'raises an error with a helpful message' do
          message = RouteCreateMessage.new({
            host: '',
            path: '/hmm?',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })
          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, "Path cannot contain '?'.")
        end
      end

      context 'when a route already exists' do
        it 'prevents conflict with hostless route on a matching domain' do
          Route.make(domain: domain, host: '', space: space)

          message = RouteCreateMessage.new({
            host: '',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })

          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, "Route already exists for domain '#{domain.name}'.")
        end

        it 'prevents conflict with matching route on host' do
          Route.make(domain: domain, host: 'a-host', space: space)

          message = RouteCreateMessage.new({
            host: 'a-host',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })

          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, "Route already exists with host 'a-host' for domain '#{domain.name}'.")
        end

        it 'prevents conflict with matching route on path' do
          Route.make(domain: domain, host: 'a-host', path: '/a-path', space: space)

          message = RouteCreateMessage.new({
            host: 'a-host',
            path: '/a-path',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              },
            },
          })

          expect {
            subject.create(message: message, space: space, domain: domain)
          }.to raise_error(RouteCreate::Error, "Route already exists with host 'a-host' and path '/a-path' for domain '#{domain.name}'.")
        end
      end

      context 'when the domain is internal' do
        let(:internal_domain) { SharedDomain.make(internal: true) }

        it 'requires host not to be a wildcard' do
          message = RouteCreateMessage.new({
            host: '*',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: internal_domain.guid }
              },
            },
          })

          expect {
            subject.create(message: message, space: space, domain: internal_domain)
          }.to raise_error(RouteCreate::Error, 'Wildcard hosts are not supported for internal domains.')
        end

        it 'disallows paths' do
          message = RouteCreateMessage.new({
            host: 'a',
            path: '/path',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: internal_domain.guid }
              },
            },
          })

          expect {
            subject.create(message: message, space: space, domain: internal_domain)
          }.to raise_error(RouteCreate::Error, 'Paths are not supported for internal domains.')
        end
      end

      context 'when using a reserved system hostname' do
        let(:system_domain) { SharedDomain.make }

        before do
          VCAP::CloudController::Config.config.set(:system_domain, system_domain.name)
          VCAP::CloudController::Config.config.set(:system_hostnames, ['host'])
        end

        it 'prevents conflict with the system domain' do
          message = RouteCreateMessage.new({
            host: 'host',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: system_domain.guid }
              },
            },
          })

          expect {
            subject.create(message: message, space: space, domain: system_domain)
          }.to raise_error(RouteCreate::Error, 'Route conflicts with a reserved system route.')
        end
      end
    end
  end
end

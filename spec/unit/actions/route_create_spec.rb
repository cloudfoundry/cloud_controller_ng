require 'spec_helper'
require 'actions/route_create'
require 'messages/route_create_message'

module VCAP::CloudController
  RSpec.describe RouteCreate do
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'amelia@cats.com', user_guid: 'gooid') }

    subject { RouteCreate.new(user_audit_info) }

    before do
      TestConfig.override(kubernetes: {})
    end

    describe '#create' do
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:org) { VCAP::CloudController::Organization.make }
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }

      context 'when successful' do
        let(:message) do
          RouteCreateMessage.new({
                                   relationships: {
                                     space: {
                                       data: { guid: space.guid }
                                     },
                                     domain: {
                                       data: { guid: domain.guid }
                                     }
                                   }
                                 })
        end

        it 'creates a route' do
          expect do
            subject.create(message:, space:, domain:)
          end.to change(Route, :count).by(1)

          route = Route.last
          expect(route.space.guid).to eq space.guid
          expect(route.domain.guid).to eq domain.guid
        end

        it 'creates an audit event' do
          expect_any_instance_of(Repositories::RouteEventRepository).
            to receive(:record_route_create).with(instance_of(Route),
                                                  user_audit_info,
                                                  message.audit_hash,
                                                  manifest_triggered: false)

          subject.create(message:, space:, domain:)
        end
      end

      context 'when given metadata' do
        let(:message_with_label) do
          RouteCreateMessage.new({
                                   relationships: {
                                     space: {
                                       data: { guid: space.guid }
                                     },
                                     domain: {
                                       data: { guid: domain.guid }
                                     }
                                   },
                                   metadata: {
                                     labels: { 'la' => 'bel' }
                                   }
                                 })
        end

        let(:message_with_annotation) do
          RouteCreateMessage.new({
                                   relationships: {
                                     space: {
                                       data: { guid: space.guid }
                                     },
                                     domain: {
                                       data: { guid: domain.guid }
                                     }
                                   },
                                   metadata: {
                                     annotations: { 'anno' => 'tation' }
                                   }
                                 })
        end

        it 'creates a route and associated labels' do
          expect do
            subject.create(message: message_with_label, space: space, domain: domain)
          end.to change(RouteLabelModel, :count).by(1)

          route = Route.last
          expect(route.labels.length).to eq(1)
          expect(route.labels[0].key_name).to eq('la')
          expect(route.labels[0].value).to eq('bel')
        end

        it 'creates a route and associated annotations' do
          expect do
            subject.create(message: message_with_annotation, space: space, domain: domain)
          end.to change(RouteAnnotationModel, :count).by(1)

          route = Route.last
          expect(route.annotations.length).to eq(1)
          expect(route.annotations[0].key_name).to eq('anno')
          expect(route.annotations[0].value).to eq('tation')
        end
      end

      context 'when given route options' do
        context 'when creating a route with loadbalancing=hash' do
          context 'with hash_header but without hash_balance' do
            let(:message_with_hash_options) do
              RouteCreateMessage.new({
                                       relationships: {
                                         space: {
                                           data: { guid: space.guid }
                                         },
                                         domain: {
                                           data: { guid: domain.guid }
                                         }
                                       },
                                       options: {
                                         loadbalancing: 'hash',
                                         hash_header: 'X-User-ID'
                                       }
                                     })
            end

            it 'creates a route with hash loadbalancing and hash_header options' do
              expect do
                subject.create(message: message_with_hash_options, space: space, domain: domain)
              end.to change(Route, :count).by(1)

              route = Route.last
              expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-User-ID' })
            end
          end

          context 'with both hash_header and hash_balance' do
            let(:message_with_hash_options) do
              RouteCreateMessage.new({
                                       relationships: {
                                         space: {
                                           data: { guid: space.guid }
                                         },
                                         domain: {
                                           data: { guid: domain.guid }
                                         }
                                       },
                                       options: {
                                         loadbalancing: 'hash',
                                         hash_header: 'X-Session-ID',
                                         hash_balance: '2'
                                       }
                                     })
            end

            it 'creates a route with hash loadbalancing, hash_header, and hash_balance options' do
              expect do
                subject.create(message: message_with_hash_options, space: space, domain: domain)
              end.to change(Route, :count).by(1)

              route = Route.last
              expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-Session-ID', 'hash_balance' => '2.0' })
            end
          end

          context 'without hash_header (required)' do
            let(:message_without_hash_header) do
              RouteCreateMessage.new({
                                       relationships: {
                                         space: {
                                           data: { guid: space.guid }
                                         },
                                         domain: {
                                           data: { guid: domain.guid }
                                         }
                                       },
                                       options: {
                                         loadbalancing: 'hash'
                                       }
                                     })
            end

            it 'raises an error indicating hash_header is required' do
              expect do
                subject.create(message: message_without_hash_header, space: space, domain: domain)
              end.to raise_error(RouteCreate::Error, 'Hash header must be present when loadbalancing is set to hash.')
            end
          end
        end

        context 'when creating a route with other loadbalancing options' do
          let(:message_with_round_robin) do
            RouteCreateMessage.new({
                                     relationships: {
                                       space: {
                                         data: { guid: space.guid }
                                       },
                                       domain: {
                                         data: { guid: domain.guid }
                                       }
                                     },
                                     options: {
                                       loadbalancing: 'round-robin'
                                     }
                                   })
          end

          it 'creates a route with the specified loadbalancing option' do
            expect do
              subject.create(message: message_with_round_robin, space: space, domain: domain)
            end.to change(Route, :count).by(1)

            route = Route.last
            expect(route.options).to include({ 'loadbalancing' => 'round-robin' })
          end
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
                                     }
                                   }
                                 })
        end

        it 'raises an error with a helpful message' do
          expect do
            subject.create(message: message, space: space, domain: inaccessible_domain)
          end.to raise_error(RouteCreate::Error, "Invalid domain. Domain '#{inaccessible_domain.name}' is not available in organization '#{space.organization.name}'.")
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
                                     }
                                   }
                                 })
        end

        it 'raises an error with a helpful message' do
          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, "Route already exists for domain '#{domain.name}'.")
        end
      end

      context 'when a port is provided' do
        let(:message) do
          RouteCreateMessage.new({
                                   host: 'wow',
                                   port: 1234,
                                   relationships: {
                                     space: {
                                       data: { guid: space.guid }
                                     },
                                     domain: {
                                       data: { guid: domain.guid }
                                     }
                                   }
                                 })
        end

        it 'raises an error with a helpful message' do
          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, "Routes with protocol 'http' do not support ports.")
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
                                     }
                                   }
                                 })
        end

        it 'raises an error with a helpful message' do
          expect do
            subject.create(message: message, space: space_with_quota, domain: domain)
          end.to raise_error(RouteCreate::Error, "Routes quota exceeded for space '#{space_with_quota.name}'.")
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
                                     }
                                   }
                                 })
        end

        it 'raises an error with a helpful message' do
          expect do
            subject.create(message: message, space: space_in_org_with_quota, domain: domain_in_org_with_quota)
          end.to raise_error(RouteCreate::Error, "Routes quota exceeded for organization '#{org_with_quota.name}'.")
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
                                     }
                                   }
                                 })
        end

        it 'raises an error with a helpful message' do
          expect do
            subject.create(message: message, space: space, domain: domain_with_long_name)
          end.to raise_error(RouteCreate::Error, 'Host combined with domain name must be no more than 253 characters.')
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
                                               }
                                             }
                                           })

          expect do
            subject.create(message: message, space: space, domain: shared_domain)
          end.to raise_error(RouteCreate::Error, 'Missing host. Routes in shared domains must have a host defined.')
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
                                               }
                                             }
                                           })
          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, 'Path is invalid.')
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
                                               }
                                             }
                                           })
          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, "Path cannot be a single '/'.")
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
                                               }
                                             }
                                           })
          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, "Path is missing the beginning '/'.")
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
                                               }
                                             }
                                           })
          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, 'Path exceeds 128 characters.')
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
                                               }
                                             }
                                           })
          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, "Path cannot contain '?'.")
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
                                               }
                                             }
                                           })

          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, "Route already exists for domain '#{domain.name}'.")
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
                                               }
                                             }
                                           })

          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, "Route already exists with host 'a-host' for domain '#{domain.name}'.")
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
                                               }
                                             }
                                           })

          expect do
            subject.create(message:, space:, domain:)
          end.to raise_error(RouteCreate::Error, "Route already exists with host 'a-host' and path '/a-path' for domain '#{domain.name}'.")
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
                                               }
                                             }
                                           })

          expect do
            subject.create(message: message, space: space, domain: internal_domain)
          end.to raise_error(RouteCreate::Error, 'Wildcard hosts are not supported for internal domains.')
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
                                               }
                                             }
                                           })

          expect do
            subject.create(message: message, space: space, domain: internal_domain)
          end.to raise_error(RouteCreate::Error, 'Paths are not supported for internal domains.')
        end

        context 'when the Kubernetes API is not configured' do
          it 'does not raise an error' do
            message = RouteCreateMessage.new({
                                               host: 'a',
                                               relationships: {
                                                 space: {
                                                   data: { guid: space.guid }
                                                 },
                                                 domain: {
                                                   data: { guid: internal_domain.guid }
                                                 }
                                               }
                                             })

            expect do
              subject.create(message: message, space: space, domain: internal_domain)
            end.not_to raise_error
          end
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
                                               }
                                             }
                                           })

          expect do
            subject.create(message: message, space: space, domain: system_domain)
          end.to raise_error(RouteCreate::Error, 'Route conflicts with a reserved system route.')
        end
      end

      describe 'ports' do
        context 'when the domain supports ports (tcp)' do
          let(:domain) { SharedDomain.make(router_group_guid: 'some-router-group') }
          let(:message) do
            RouteCreateMessage.new({
                                     port: 1234,
                                     relationships: {
                                       space: {
                                         data: { guid: space.guid }
                                       },
                                       domain: {
                                         data: { guid: domain.guid }
                                       }
                                     }
                                   })
          end
          let(:routing_api_client) { instance_double(RoutingApi::Client) }
          let(:router_group) { instance_double(RoutingApi::RouterGroup) }

          before do
            allow(CloudController::DependencyLocator).to receive_message_chain(:instance, :routing_api_client).
              and_return(routing_api_client)
            allow(routing_api_client).to receive_messages(router_group: router_group, enabled?: true)
            allow(router_group).to receive_messages(type: 'tcp', reservable_ports: [1234])
          end

          context 'when the port is available' do
            it 'creates a route with the port' do
              expect do
                subject.create(message:, space:, domain:)
              end.to change(Route, :count).by(1)

              route = Route.last
              expect(route.port).to eq(1234)
            end
          end

          context 'when a route with the same domain and port exist' do
            let!(:duplicate_route) { Route.make(domain: domain, host: '', port: 1234, space: space) }

            it 'errors to prevent creating a duplicate route' do
              expect do
                subject.create(message:, space:, domain:)
              end.to raise_error(RouteCreate::Error, "Route already exists with port '1234' for domain '#{domain.name}'.")
            end
          end

          context 'when the port is not reservable for the router group' do
            before do
              allow(router_group).to receive(:reservable_ports).and_return([])
            end

            it 'errors and respects the reserved port' do
              expect do
                subject.create(message:, space:, domain:)
              end.to raise_error(RouteCreate::Error, "Port '1234' is not available. Try a different port or use a different domain.")
            end
          end

          context 'when the space quota limit on reserved ports has been maxed out' do
            let!(:space_quota_definition) { SpaceQuotaDefinition.make(total_reserved_route_ports: 0, organization: org) }
            let!(:space) do
              Space.make(space_quota_definition: space_quota_definition, organization: org)
            end

            it 'raises an error with a helpful message' do
              expect do
                subject.create(message:, space:, domain:)
              end.to raise_error(RouteCreate::Error, "Reserved route ports quota exceeded for space '#{space.name}'.")
            end
          end

          context 'when the org quota limit on reserved ports has been maxed out' do
            let!(:org_quota_definition) { QuotaDefinition.make(total_reserved_route_ports: 0) }
            let!(:org_with_quota) { Organization.make(quota_definition: org_quota_definition) }
            let!(:space) { Space.make(organization: org_with_quota) }
            let(:domain) { Domain.make(owning_organization: org_with_quota) }

            it 'raises an error with a helpful message' do
              expect do
                subject.create(message:, space:, domain:)
              end.to raise_error(RouteCreate::Error, "Reserved route ports quota exceeded for organization '#{org_with_quota.name}'.")
            end
          end

          context 'no port is provided' do
            let(:message) do
              RouteCreateMessage.new({
                                       relationships: {
                                         space: {
                                           data: { guid: space.guid }
                                         },
                                         domain: {
                                           data: { guid: domain.guid }
                                         }
                                       }
                                     })
            end

            let(:router_group) { double('router_group1', type: 'tcp', guid: 'router_group_guid', reservable_ports: [1024]) }
            let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client) }

            before do
              allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
              allow(routing_api_client).to receive_messages(enabled?: true, router_group: router_group)
            end

            it 'randomly assigns an available port' do
              expect do
                subject.create(message:, space:, domain:)
              end.to change(Route, :count).by(1)

              route = Route.last
              expect(route.port).to eq(1234)
            end
          end

          context 'when path is provided' do
            let(:message) do
              RouteCreateMessage.new({
                                       port: 1234,
                                       path: '/monkeys',
                                       relationships: {
                                         space: {
                                           data: { guid: space.guid }
                                         },
                                         domain: {
                                           data: { guid: domain.guid }
                                         }
                                       }
                                     })
            end

            it 'errors with a helpful error message' do
              expect do
                subject.create(message:, space:, domain:)
              end.to raise_error(RouteCreate::Error, 'Paths are not supported for TCP routes.')
            end
          end
        end
      end
    end
  end
end

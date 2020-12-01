require 'spec_helper'
require 'kubernetes/api_client'

RSpec.describe Kubernetes::RouteResourceManager do
  let(:k8s_client) { instance_double(Kubernetes::ApiClient) }
  subject(:route_resource_manager) { Kubernetes::RouteResourceManager.new(k8s_client) }
  before do
    TestConfig.override(
      kubernetes: {
        host_url: 'https://kubernetes.example.com',
        workloads_namespace: 'cf-workloads',
      }
    )
  end

  describe '#create_route' do
    let(:route) { VCAP::CloudController::Route.make }
    let(:internal_domain?) { route.internal? }
    let(:route_crd_hash) do
      {
        metadata: {
          name: route.guid,
          namespace: 'cf-workloads',
          labels: {
            'app.kubernetes.io/name' => route.guid,
            'app.kubernetes.io/version' => '0.0.0',
            'app.kubernetes.io/managed-by' => 'cloudfoundry',
            'app.kubernetes.io/component' => 'cf-networking',
            'app.kubernetes.io/part-of' => 'cloudfoundry',
            'cloudfoundry.org/org_guid' => route.space.organization_guid,
            'cloudfoundry.org/space_guid' => route.space.guid,
            'cloudfoundry.org/domain_guid' => route.domain.guid,
            'cloudfoundry.org/route_guid' => route.guid
          }
        },
        spec: {
          host: route.host,
          path: route.path,
          url: route.fqdn,
          domain: {
            name: route.domain.name,
            internal: internal_domain?
          },
          destinations: []
        }
      }
    end

    it 'create a route resource in Kubernetes' do
      allow(k8s_client).to receive(:create_route).with(any_args)

      subject.create_route(route)

      expect(k8s_client).to have_received(:create_route).with(Kubeclient::Resource.new(route_crd_hash)).once
    end

    context 'when the domain is internal' do
      let(:internal_domain?) { true }

      let(:space) { VCAP::CloudController::Space.make }
      let(:domain) { VCAP::CloudController::PrivateDomain.make(internal: true, owning_organization: space.organization) }
      let(:route) { VCAP::CloudController::Route.make(space: space, domain: domain) }

      it 'sets internal to true' do
        allow(k8s_client).to receive(:create_route).with(any_args)

        subject.create_route(route)

        expect(k8s_client).to have_received(:create_route).with(Kubeclient::Resource.new(route_crd_hash)).once
      end
    end

    context 'when there are k8s errors' do
      let(:error) { RuntimeError.new('boom') }
      before do
        allow(k8s_client).to receive(:create_route).and_raise(error)
      end

      it 'bubbles up the error' do
        expect {
          subject.create_route(route)
        }.to raise_error(error)
      end
    end
  end

  describe '#delete_route' do
    let(:route) { VCAP::CloudController::Route.make(guid: 'theguid') }

    it 'deletes a route resource in Kubernetes' do
      allow(k8s_client).to receive(:delete_route).with(any_args)

      subject.delete_route(route)

      expect(k8s_client).to have_received(:delete_route).with('theguid', 'cf-workloads')
    end
  end

  describe '#update_destinations' do
    let(:route) { VCAP::CloudController::Route.make(path: '/some/path') }
    let(:route_cr) do
      Kubeclient::Resource.new({
        kind: 'Route',
        apiVersion: 'foobar.org/v1alpha1',
        metadata: {
          name: route.guid,
          namespace: 'cf-workloads',
          labels: {
            'app.kubernetes.io/name' => route.guid,
            'app.kubernetes.io/version' => '0.0.0',
            'app.kubernetes.io/managed-by' => 'cloudfoundry',
            'app.kubernetes.io/component' => 'cf-networking',
            'app.kubernetes.io/part-of' => 'cloudfoundry',
            'cloudfoundry.org/org_guid' => route.space.organization_guid,
            'cloudfoundry.org/space_guid' => route.space.guid,
            'cloudfoundry.org/domain_guid' => route.domain.guid,
            'cloudfoundry.org/route_guid' => route.guid
          }
        },
        spec: {
          host: route.host,
          path: route.path,
          url: "#{route.fqdn}/some/path",
          domain: {
            name: route.domain.name,
            internal: route.internal?
          },
          destinations: []
        }
      })
    end

    before do
      allow(k8s_client).to receive(:get_route).with(route.guid, 'cf-workloads').and_return(route_cr)
      allow(k8s_client).to receive(:update_route).with(any_args)
    end

    context 'when there are route mappings' do
      let(:weight) { nil }
      let(:myapp) { VCAP::CloudController::AppModel.make(name: 'myapp') }
      let!(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(route: route, app: myapp, process_type: 'web', weight: weight) }

      it 'sets the destinations and updates the route cr' do
        expected_hash = Kubeclient::Resource.new(route_cr.to_hash)
        expected_hash.spec.destinations = [{
          guid: route_mapping.guid,
          port: route_mapping.presented_port,
          app: {
            guid: route_mapping.app_guid,
            process: {
              type: route_mapping.process_type,
            },
          },
          selector: {
            matchLabels: {
              'cloudfoundry.org/app_guid' => route_mapping.app_guid,
              'cloudfoundry.org/process_type' => route_mapping.process_type,
            },
          },
        }]

        expect(k8s_client).to receive(:update_route) do |actual|
          expect(expected_hash.to_hash).to eq(actual.to_hash)
        end

        route_resource_manager.update_destinations(route)
      end

      context 'when the route mappings have weights that should sum to 100' do
        let(:myapp2) { VCAP::CloudController::AppModel.make(name: 'myapp') }
        let!(:route_mapping2) { VCAP::CloudController::RouteMappingModel.make(route: route, app: myapp2, process_type: 'web', weight: 30) }

        let(:weight) { 70 }

        it 'configures weight on each destination and updates the Route CR' do
          expected_hash = Kubeclient::Resource.new(route_cr.to_hash)
          expected_hash.spec.destinations = [
            {
              guid: route_mapping.guid,
              port: route_mapping.presented_port,
              app: {
                guid: route_mapping.app_guid,
                process: {
                  type: route_mapping.process_type,
                },
              },
              selector: {
                matchLabels: {
                  'cloudfoundry.org/app_guid' => route_mapping.app_guid,
                  'cloudfoundry.org/process_type' => route_mapping.process_type,
                },
              },
              weight: 70,
            },
            {
              guid: route_mapping2.guid,
              port: route_mapping2.presented_port,
              app: {
                guid: route_mapping2.app_guid,
                process: {
                  type: route_mapping2.process_type,
                },
              },
              selector: {
                matchLabels: {
                  'cloudfoundry.org/app_guid' => route_mapping2.app_guid,
                  'cloudfoundry.org/process_type' => route_mapping2.process_type,
                },
              },
              weight: 30,
            }
          ]

          expect(k8s_client).to receive(:update_route) do |actual|
            expect(expected_hash.to_hash).to eq(actual.to_hash)
          end

          route_resource_manager.update_destinations(route)
        end
      end

      context 'when there are k8s errors' do
        let(:error) { RuntimeError.new('Boom') }

        before do
          allow(k8s_client).to receive(:update_route).and_raise(error)
        end

        it 'bubbles up the error' do
          expect {
            subject.update_destinations(route)
          }.to raise_error(error)
        end
      end

      context 'when there is a k8s conflict error' do
        let(:error) { ::Kubernetes::ApiClient::ConflictError.new('boom') }

        before do
          # raise a 409 twice, then succeed
          expect(k8s_client).to receive(:update_route).once.with(any_args).and_raise(error)
          expect(k8s_client).to receive(:update_route).once.with(any_args).and_raise(error)
          expect(k8s_client).to receive(:update_route).once.with(any_args)
        end

        it 'retries 3 times, fetching the route to patch each time' do
          expect {
            subject.update_destinations(route)
          }.not_to raise_error
          expect(k8s_client).to have_received(:get_route).exactly(3).times
        end
      end
    end
  end
end

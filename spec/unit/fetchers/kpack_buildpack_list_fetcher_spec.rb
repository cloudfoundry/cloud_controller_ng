require 'spec_helper'
require 'fetchers/kpack_buildpack_list_fetcher'

module VCAP::CloudController
  RSpec.describe KpackBuildpackListFetcher do
    let(:fetcher) { KpackBuildpackListFetcher.new }
    let(:client) { instance_double(Kubernetes::ApiClient) }
    let(:filters) { {} }

    let(:cflinuxfs3_stackname) { 'cflinuxfs3-stack' }
    let(:builder_namespace) { 'custom-cf-workloads-staging' }

    let(:default_builder_created_at_str) { '2020-06-27T03:13:07Z' }
    let(:default_builder_ready_at_str) { '2020-06-27T03:15:46Z' }

    let(:default_builder_obj) {
      Kubeclient::Resource.new(
        kind: 'Builder',
        metadata: {
          creationTimestamp: default_builder_created_at_str,
        },
        spec: {
          order: [
            { group: [{ id: 'paketo-community/ruby' }] },
            { group: [{ id: 'paketo-buildpacks/java' }] },
          ],
          stack: cflinuxfs3_stackname,
        },
        status: {
          builderMetadata: [
            { id: 'paketo-community/mri', version: '0.0.131' },
            { id: 'paketo-community/bundler', version: '0.0.117' },
            { id: 'paketo-community/bundle-install', version: '0.0.22' },
            { id: 'paketo-community/rackup', version: '0.0.13' },
            { id: 'paketo-buildpacks/maven', version: '1.4.5' },
            { id: 'paketo-buildpacks/java', version: '1.14.0' },
            { id: 'paketo-community/ruby', version: '0.0.11' },
          ],
          conditions: [
            {
              lastTransitionTime: default_builder_ready_at_str,
              status: 'True',
              type: 'Ready',
            }
          ],
          stack: {
            id: 'org.cloudfoundry.stacks.cflinuxfs3'
          }
        }
      )
    }

    before do
      TestConfig.override(
        kubernetes: {
          host_url: 'https://some-url',
          kpack: { builder_namespace: builder_namespace },
        },
      )
      allow(CloudController::DependencyLocator.instance).to receive(:k8s_api_client).and_return(client)
      allow(client).to receive(:get_builder).and_return(default_builder_obj)
    end

    describe '#fetch_all' do
      let(:message) { BuildpacksListMessage.from_params(filters) }
      subject(:result) { fetcher.fetch_all(message) }

      it 'returns a list of paketo buildpacks' do
        expect(result.length).to(eq(2))
        buildpack1, buildpack2 = result

        expect(buildpack1.name).to(eq('paketo-community/ruby'))
        expect(buildpack1.id).to(eq('paketo-community/ruby@0.0.11'))
        expect(buildpack1.filename).to(eq('paketo-community/ruby@0.0.11'))
        expect(buildpack1.stack).to(eq('org.cloudfoundry.stacks.cflinuxfs3'))
        expect(buildpack1.guid).to(be_blank)
        expect(buildpack1.state).to(eq('READY'))
        expect(buildpack1.position).to(eq(0))
        expect(buildpack1.enabled).to(eq(true))
        expect(buildpack1.locked).to(eq(false))
        expect(buildpack1.created_at).to(eq(Time.parse(default_builder_created_at_str)))
        expect(buildpack1.updated_at).to(eq(Time.parse(default_builder_ready_at_str)))
        expect(buildpack1.labels).to(be_empty)
        expect(buildpack1.annotations).to(be_empty)

        expect(buildpack2.name).to(eq('paketo-buildpacks/java'))
        expect(buildpack2.id).to(eq('paketo-buildpacks/java@1.14.0'))
        expect(buildpack2.filename).to(eq('paketo-buildpacks/java@1.14.0'))
        expect(buildpack2.stack).to(eq('org.cloudfoundry.stacks.cflinuxfs3'))
        expect(buildpack2.guid).to(be_blank)
        expect(buildpack2.state).to(eq('READY'))
        expect(buildpack2.position).to(eq(0))
        expect(buildpack2.enabled).to(eq(true))
        expect(buildpack2.locked).to(eq(false))
        expect(buildpack2.created_at).to(eq(Time.parse(default_builder_created_at_str)))
        expect(buildpack2.updated_at).to(eq(Time.parse(default_builder_ready_at_str)))
        expect(buildpack2.labels).to(be_empty)
        expect(buildpack2.annotations).to(be_empty)

        expect(client).to have_received(:get_builder).with('cf-default-builder', builder_namespace)
      end

      context 'without a message' do
        let(:message) { nil }
        subject(:result) { fetcher.fetch_all }

        it 'can be called without a message' do
          expect(result.length).to(eq(2))
          expect(client).to have_received(:get_builder).with('cf-default-builder', builder_namespace)
        end
      end

      context 'when there are no status conditions' do
        before do
          default_builder_obj.status.conditions = []
        end

        it 'uses the default builder creation time for updated_at' do
          expect(result.length).to(eq(2))
          buildpack1, buildpack2 = result

          expect(buildpack1.updated_at).to(eq(Time.parse(default_builder_created_at_str)))
          expect(buildpack2.updated_at).to(eq(Time.parse(default_builder_created_at_str)))
        end

        it 'has status AWAITING_UPLOAD' do
          expect(result.length).to(eq(2))
          buildpack1, buildpack2 = result

          expect(buildpack1.state).to(eq('AWAITING_UPLOAD'))
          expect(buildpack2.state).to(eq('AWAITING_UPLOAD'))
        end
      end
    end
  end
end

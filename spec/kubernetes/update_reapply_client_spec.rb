require 'spec_helper'
require 'kubernetes/update_reapply_client'

module Kubernetes
  RSpec.describe UpdateReapplyClient do
    subject(:reapply_client) { UpdateReapplyClient.new(api_client) }
    let(:api_client) { instance_double(ApiClient) }
    let(:namespace) { 'cf-bogus' }

    describe '#apply_route_update' do
      let(:name) { 'route' }
      let(:remote_route) { Kubeclient::Resource.new(
        kind: 'Route',
        metadata: {
          'cloudfoundry.org/bogus_guid' => 'bogus',
        },
        spec: {
          host: 'internet',
        },
      )
      }

      before do
        allow(api_client).to receive(:get_route).with(name, namespace).and_return(remote_route)
        allow(api_client).to receive(:update_route)
      end

      it 'applies the update in the block' do
        reapply_client.apply_route_update(name, namespace) do |remote_route|
          remote_route.spec.domain = 'website.biz'
          remote_route
        end

        expect(api_client).to have_received(:update_route) do |update|
          expect(update.spec.domain).to eq('website.biz')
          expect(update.spec.host).to eq('internet')
        end
      end

      context 'when there is a transient k8s conflict error' do
        let(:error) { ::Kubernetes::ApiClient::ConflictError.new('boom') }

        before do
          # raise a 409 twice, then succeed
          expect(api_client).to receive(:update_route).once.with(any_args).and_raise(error)
          expect(api_client).to receive(:update_route).once.with(any_args).and_raise(error)
          expect(api_client).to receive(:update_route).once.with(any_args)
        end

        it 'retries 3 times, fetching the route to patch each time' do
          expect {
            reapply_client.apply_route_update(name, namespace) do |route|
              route.spec = {}
              route
            end
          }.not_to raise_error

          expect(api_client).to have_received(:get_route).exactly(3).times
        end
      end

      it 'errors when no block is provided' do
        expect do
          reapply_client.apply_route_update(name, namespace)
        end.to raise_error(NoMethodError)
      end

      it 'errors when the block provided doesnt take an arg' do
        expect do
          reapply_client.apply_route_update(name, namespace) do
            puts 'lul'
          end
        end.to raise_error(UpdateReapplyClient::MalformedBlockError)
      end
    end

    describe '#apply_image_update' do
      let(:name) { 'image' }
      let(:remote_image) { Kubeclient::Resource.new(
        kind: 'Image',
        metadata: {
          'cloudfoundry.org/bogus_guid' => 'bogus',
        },
        spec: {
          host: 'internet',
        },
      )
      }

      before do
        allow(api_client).to receive(:get_image).with(name, namespace).and_return(remote_image)
        allow(api_client).to receive(:update_image)
      end

      it 'applies the update in the block' do
        reapply_client.apply_image_update(name, namespace) do |remote_image|
          remote_image.spec.domain = 'website.biz'
          remote_image
        end

        expect(api_client).to have_received(:update_image) do |update|
          expect(update.spec.domain).to eq('website.biz')
          expect(update.spec.host).to eq('internet')
        end
      end

      context 'when there is a transient k8s conflict error' do
        let(:error) { ::Kubernetes::ApiClient::ConflictError.new('boom') }

        before do
          # raise a 409 twice, then succeed
          expect(api_client).to receive(:update_image).once.with(any_args).and_raise(error)
          expect(api_client).to receive(:update_image).once.with(any_args).and_raise(error)
          expect(api_client).to receive(:update_image).once.with(any_args)
        end

        it 'retries 3 times, fetching the image to patch each time' do
          expect {
            reapply_client.apply_image_update(name, namespace) do |image|
              image.spec = {}
              image
            end
          }.not_to raise_error

          expect(api_client).to have_received(:get_image).exactly(3).times
        end
      end

      it 'errors when no block is provided' do
        expect do
          reapply_client.apply_image_update(name, namespace)
        end.to raise_error(NoMethodError)
      end

      it 'errors when the block provided doesnt take an arg' do
        expect do
          reapply_client.apply_image_update(name, namespace) do
            puts 'lul'
          end
        end.to raise_error(UpdateReapplyClient::MalformedBlockError)
      end
    end

    describe '#apply_builder_update' do
      let(:name) { 'builder' }
      let(:remote_builder) do
        Kubeclient::Resource.new(
          kind: 'Builder',
          metadata: {
            'cloudfoundry.org/bogus_guid' => 'bogus',
          },
          spec: {
            host: 'internet',
          },
        )
      end

      before do
        allow(api_client).to receive(:get_builder).with(name, namespace).and_return(remote_builder)
        allow(api_client).to receive(:update_builder)
      end

      it 'applies the update in the block' do
        reapply_client.apply_builder_update(name, namespace) do |remote_builder|
          remote_builder.spec.domain = 'website.biz'
          remote_builder
        end

        expect(api_client).to have_received(:update_builder) do |update|
          expect(update.spec.domain).to eq('website.biz')
          expect(update.spec.host).to eq('internet')
        end
      end

      context 'when there is a transient k8s conflict error' do
        let(:error) { ::Kubernetes::ApiClient::ConflictError.new('boom') }

        before do
          # raise a 409 twice, then succeed
          expect(api_client).to receive(:update_builder).once.with(any_args).and_raise(error)
          expect(api_client).to receive(:update_builder).once.with(any_args).and_raise(error)
          expect(api_client).to receive(:update_builder).once.with(any_args)
        end

        it 'retries 3 times, fetching the builder to patch each time' do
          expect {
            reapply_client.apply_builder_update(name, namespace) do |builder|
              builder.spec = {}
              builder
            end
          }.not_to raise_error

          expect(api_client).to have_received(:get_builder).exactly(3).times
        end
      end

      it 'errors when no block is provided' do
        expect do
          reapply_client.apply_builder_update(name, namespace)
        end.to raise_error(NoMethodError)
      end

      it 'errors when the block provided doesnt take an arg' do
        expect do
          reapply_client.apply_builder_update(name, namespace) do
            puts 'lul'
          end
        end.to raise_error(UpdateReapplyClient::MalformedBlockError)
      end
    end
  end
end

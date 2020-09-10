require 'spec_helper'
require 'kubernetes/api_client'

RSpec.describe Kubernetes::ApiClient do
  let(:build_kube_client) { double(Kubeclient::Client) }
  let(:kpack_kube_client) { double(Kubeclient::Client) }
  let(:route_kube_client) { double(Kubeclient::Client) }
  subject(:k8s_api_client) do
    Kubernetes::ApiClient.new(
      build_kube_client: build_kube_client,
      kpack_kube_client: kpack_kube_client,
      route_kube_client: route_kube_client,
    )
  end

  context 'image resources' do
    describe '#create_image' do
      let(:resource_config) { { metadata: { name: 'resource-name' } } }

      it 'proxies call to kubernetes client with the same args' do
        allow(build_kube_client).to receive(:create_image).with(resource_config)

        subject.create_image(resource_config)

        expect(build_kube_client).to have_received(:create_image).with(resource_config).once
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(build_kube_client).to receive(:create_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.create_image(resource_config)
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end

    describe '#get_image' do
      let(:response) { double(Kubeclient::Resource) }

      it 'fetches the image from Kubernetes' do
        allow(build_kube_client).to receive(:get_image).with('name', 'namespace').and_return(response)

        image = subject.get_image('name', 'namespace')
        expect(image).to eq(response)
      end

      context 'when the image is not present' do
        it 'returns nil' do
          allow(build_kube_client).to receive(:get_image).with('name', 'namespace').and_raise(Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

          image = subject.get_image('name', 'namespace')
          expect(image).to be_nil
        end
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(build_kube_client).to receive(:get_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.get_image('name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end

    describe '#update_image' do
      let(:resource_config) { { metadata: { name: 'resource-name' } } }
      let(:response) { double(Kubeclient::Resource) }

      it 'proxies call to kubernetes client with the same args' do
        allow(build_kube_client).to receive(:update_image).with(resource_config)

        subject.update_image(resource_config)

        expect(build_kube_client).to have_received(:update_image).with(resource_config).once
      end

      context 'when there is an error' do
        let(:error) { Kubeclient::HttpError.new(422, 'foo', 'bar') }
        let(:logger) { instance_double(Steno::Logger, error: nil) }
        before do
          allow(build_kube_client).to receive(:update_image).and_raise(error)
          allow(Steno).to receive(:logger).and_return(logger)
        end

        it 'raises as an ApiError' do
          allow(build_kube_client).to receive(:update_image).and_raise(error)

          expect {
            subject.update_image(resource_config)
          }.to raise_error(CloudController::Errors::ApiError)
        end

        context 'when the error is a 409' do
          let(:error) { Kubeclient::HttpError.new(409, 'foo', 'bar') }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_image(resource_config)
            }.to raise_error(Kubernetes::ApiClient::ConflictError)
            expect(logger).to have_received(:error).with('update_image', error: /status code/, response: error.response, backtrace: error.backtrace)
          end
        end
      end
    end

    describe '#delete_image' do
      it 'proxies call to kubernetes client with the same args' do
        expect(build_kube_client).to receive(:delete_image).with('resource-name', 'namespace')

        subject.delete_image('resource-name', 'namespace')
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(build_kube_client).to receive(:delete_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.delete_image('resource-name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError)
        end

        context 'when the image is not present' do
          it 'returns nil' do
            allow(build_kube_client).to receive(:delete_image).with('name', 'namespace').and_raise(
              Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

            image = subject.delete_image('name', 'namespace')
            expect(image).to be_nil
          end
        end
      end
    end
  end

  context 'route resources' do
    describe '#create_route' do
      let(:config_hash) { { metadata: { name: 'resource-name' } } }
      let(:resource_config) { Kubeclient::Resource.new(config_hash) }

      it 'proxies call to kubernetes client with the same args' do
        allow(route_kube_client).to receive(:create_route).with(resource_config)

        subject.create_route(resource_config)

        expect(route_kube_client).to have_received(:create_route).with(resource_config).once
      end

      context 'when there is an error' do
        before do
          allow(route_kube_client).to receive(:create_route).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))
        end

        context 'when the config is a Kubeclient::Resource' do
          let(:resource_config) { Kubeclient::Resource.new(config_hash) }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.create_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the config is a hash with symbol keys' do
          let(:resource_config) { config_hash.symbolize_keys }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.create_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the config is a hash with string keys' do
          let(:resource_config) { config_hash.stringify_keys }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.create_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the resource config is missing metadata' do
          let(:resource_config) { {} }

          it 'raises as an ApiError without a resource name' do
            expect {
              subject.create_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError)
          end
        end
      end
    end

    describe '#get_route' do
      let(:response) { double(Kubeclient::Resource) }

      it 'fetches the route resource from Kubernetes' do
        allow(route_kube_client).to receive(:get_route).with('resource-name', 'namespace').and_return(response)

        image = subject.get_route('resource-name', 'namespace')
        expect(image).to eq(response)
      end

      context 'when the route resource is not present' do
        it 'returns nil' do
          allow(route_kube_client).to receive(:get_route).with('resource-name', 'namespace').
            and_raise(Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

          image = subject.get_route('resource-name', 'namespace')
          expect(image).to be_nil
        end
      end

      context 'when there is an error' do
        let(:error) { Kubeclient::HttpError.new(422, 'foo', 'bar') }
        let(:logger) { instance_double(Steno::Logger, error: nil) }
        before do
          allow(route_kube_client).to receive(:get_route).and_raise(error)
          allow(Steno).to receive(:logger).and_return(logger)
        end

        it 'raises as an ApiError' do
          expect {
            subject.get_route('resource-name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          expect(logger).to have_received(:error).with('get_route', error: /status code/, response: error.response, backtrace: error.backtrace)
        end
      end
    end

    describe '#update_route' do
      let(:config_hash) { { metadata: { name: 'resource-name' } } }
      let(:resource_config) { Kubeclient::Resource.new(config_hash) }

      let(:response) { double(Kubeclient::Resource) }

      it 'proxies call to kubernetes client with the same args' do
        allow(route_kube_client).to receive(:update_route).with(resource_config)

        subject.update_route(resource_config)

        expect(route_kube_client).to have_received(:update_route).with(resource_config).once
      end

      context 'when there is an error' do
        let(:error) { Kubeclient::HttpError.new(422, 'foo', 'bar') }
        let(:logger) { instance_double(Steno::Logger, error: nil) }
        before do
          allow(route_kube_client).to receive(:update_route).and_raise(error)
          allow(Steno).to receive(:logger).and_return(logger)
        end

        context 'when the config is a Kubeclient::Resource' do
          let(:resource_config) { Kubeclient::Resource.new(config_hash) }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
            expect(logger).to have_received(:error).with('update_route', error: /status code/, response: error.response, backtrace: error.backtrace)
          end
        end

        context 'when the error is a 409' do
          let(:error) { Kubeclient::HttpError.new(409, 'foo', 'bar') }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(Kubernetes::ApiClient::ConflictError)
            expect(logger).to have_received(:error).with('update_route', error: /status code/, response: error.response, backtrace: error.backtrace)
          end
        end

        context 'when the config is a hash with symbol keys' do
          let(:resource_config) { config_hash.symbolize_keys }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the config is a hash with string keys' do
          let(:resource_config) { config_hash.stringify_keys }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the resource config is missing metadata' do
          let(:resource_config) { {} }

          it 'raises as an ApiError without a resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError)
          end
        end
      end
    end

    describe '#delete_route' do
      it 'proxies call to kubernetes client with the same args' do
        expect(route_kube_client).to receive(:delete_route).with('resource-name', 'namespace')

        subject.delete_route('resource-name', 'namespace')
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(route_kube_client).to receive(:delete_route).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.delete_route('resource-name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
        end

        context 'when the route resource is not present' do
          it 'returns nil' do
            allow(route_kube_client).to receive(:delete_route).with('name', 'namespace').and_raise(
              Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

            image = subject.delete_route('name', 'namespace')
            expect(image).to be_nil
          end
        end
      end
    end
  end

  context 'builder resources' do
    describe '#create_builder' do
      let(:resource_config) { { metadata: { name: 'resource-name' } } }

      it 'proxies call to kubernetes client with the same args' do
        allow(kpack_kube_client).to receive(:create_builder).with(resource_config)

        subject.create_builder(resource_config)

        expect(kpack_kube_client).to have_received(:create_builder).with(resource_config).once
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(kpack_kube_client).to receive(:create_builder).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.create_builder(resource_config)
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end

    describe '#delete_builder' do
      it 'proxies calls to the k8s client with the same args' do
        allow(kpack_kube_client).to receive(:delete_builder).with('name', 'namespace')

        subject.delete_builder('name', 'namespace')

        expect(kpack_kube_client).to have_received(:delete_builder).with('name', 'namespace').once
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(kpack_kube_client).to receive(:delete_builder).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.delete_builder('name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end

      context 'when it returns a 404' do
        it 'eats the error' do
          allow(kpack_kube_client).to receive(:delete_builder).
            and_raise(Kubeclient::ResourceNotFoundError.new(404, 'builders not found', '{"kind": "Status"}'))

          expect {
            subject.delete_builder('name', 'namespace')
          }.not_to raise_error
        end
      end
    end

    describe '#get_builder' do
      let(:response) { double(Kubeclient::Resource) }

      it 'fetches the builder from Kubernetes' do
        allow(kpack_kube_client).to receive(:get_builder).with('name', 'namespace').and_return(response)

        builder = subject.get_builder('name', 'namespace')
        expect(builder).to eq(response)
      end

      context 'when the builder is not present' do
        it 'returns nil' do
          allow(kpack_kube_client).to receive(:get_builder).with('name', 'namespace').
            and_raise(Kubeclient::ResourceNotFoundError.new(404, 'builders not found', '{"kind": "Status"}'))

          builder = subject.get_builder('name', 'namespace')
          expect(builder).to be_nil
        end
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(kpack_kube_client).to receive(:get_builder).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.get_builder('name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end

    describe '#update_builder' do
      let(:resource_config) { { metadata: { name: 'resource-name' } } }
      let(:response) { double(Kubeclient::Resource) }

      it 'proxies call to kubernetes client with the same args' do
        allow(kpack_kube_client).to receive(:update_builder).with(resource_config)

        subject.update_builder(resource_config)

        expect(kpack_kube_client).to have_received(:update_builder).with(resource_config).once
      end

      context 'when there is an error' do
        let(:error) { Kubeclient::HttpError.new(422, 'foo', 'bar') }
        let(:logger) { instance_double(Steno::Logger, error: nil) }
        before do
          allow(kpack_kube_client).to receive(:update_builder).and_raise(error)
          allow(Steno).to receive(:logger).and_return(logger)
        end

        it 'raises as an ApiError' do
          allow(kpack_kube_client).to receive(:update_builder).and_raise(error)

          expect {
            subject.update_builder(resource_config)
          }.to raise_error(CloudController::Errors::ApiError)
        end

        context 'when the error is a 409' do
          let(:error) { Kubeclient::HttpError.new(409, 'foo', 'bar') }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_builder(resource_config)
            }.to raise_error(Kubernetes::ApiClient::ConflictError)
            expect(logger).to have_received(:error).with('update_builder', error: /status code/, response: error.response, backtrace: error.backtrace)
          end
        end
      end
    end
  end
end

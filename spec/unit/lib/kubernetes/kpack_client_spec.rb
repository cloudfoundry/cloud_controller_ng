require 'spec_helper'
require 'kubernetes/kpack_client'

RSpec.describe Kubernetes::KpackClient do
  let(:build_kube_client) { double(Kubeclient::Client) }
  let(:kpack_kube_client) { double(Kubeclient::Client) }
  subject(:kpack_client) { Kubernetes::KpackClient.new(build_kube_client: build_kube_client, kpack_kube_client: kpack_kube_client) }

  describe '#create_image' do
    let(:args) { [1, 2, 'a', 'b'] }

    it 'proxies call to kubernetes client with the same args' do
      allow(build_kube_client).to receive(:create_image).with(any_args)

      subject.create_image(*args)

      expect(build_kube_client).to have_received(:create_image).with(*args).once
    end

    context 'when there is an error' do
      it 'raises as an ApiError' do
        allow(build_kube_client).to receive(:create_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

        expect {
          subject.create_image(*args)
        }.to raise_error(CloudController::Errors::ApiError)
      end
    end
  end

  describe '#get_image' do
    let(:args) { [1, 2, 'a', 'b'] }
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

  describe '#get_custom_builder' do
    let(:args) { [1, 2, 'a', 'b'] }
    let(:response) { double(Kubeclient::Resource) }

    it 'fetches the custom builder from Kubernetes' do
      allow(kpack_kube_client).to receive(:get_custom_builder).with('name', 'namespace').and_return(response)

      custombuilder = subject.get_custom_builder('name', 'namespace')
      expect(custombuilder).to eq(response)
    end

    context 'when the custombuilder is not present' do
      it 'returns nil' do
        allow(kpack_kube_client).to receive(:get_custom_builder).with('name', 'namespace').
          and_raise(Kubeclient::ResourceNotFoundError.new(404, 'custombuilders not found', '{"kind": "Status"}'))

        custombuilder = subject.get_custom_builder('name', 'namespace')
        expect(custombuilder).to be_nil
      end
    end

    context 'when there is an error' do
      it 'raises as an ApiError' do
        allow(kpack_kube_client).to receive(:get_custom_builder).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

        expect {
          subject.get_custom_builder('name', 'namespace')
        }.to raise_error(CloudController::Errors::ApiError)
      end
    end
  end

  describe '#update_image' do
    let(:args) { [1, 2, 'a', 'b'] }
    let(:response) { double(Kubeclient::Resource) }

    it 'proxies call to kubernetes client with the same args' do
      allow(build_kube_client).to receive(:update_image).with(any_args)

      subject.update_image(*args)

      expect(build_kube_client).to have_received(:update_image).with(*args).once
    end

    context 'when there is an error' do
      it 'raises as an ApiError' do
        allow(build_kube_client).to receive(:update_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

        expect {
          subject.update_image(*args)
        }.to raise_error(CloudController::Errors::ApiError)
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

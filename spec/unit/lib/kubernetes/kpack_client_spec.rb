require 'spec_helper'
require 'kubernetes/kpack_client'

RSpec.describe Kubernetes::KpackClient do
  describe '#create_image' do
    let(:kube_client) { double(Kubeclient) }
    let(:args) { [1, 2, 'a', 'b'] }
    subject(:kpack_client) { Kubernetes::KpackClient.new(kube_client) }

    it 'proxies call to kubernetes client with the same args' do
      allow(kube_client).to receive(:create_image).with(any_args)

      subject.create_image(*args)

      expect(kube_client).to have_received(:create_image).with(*args).once
    end

    context 'when there is an error' do
      it 'raises as an ApiError' do
        allow(kube_client).to receive(:create_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

        expect {
          subject.create_image(*args)
        }.to raise_error(CloudController::Errors::ApiError)
      end
    end
  end

  describe '#get_image' do
    let(:kube_client) { double(Kubeclient) }
    let(:args) { [1, 2, 'a', 'b'] }
    let(:response) { double(Kubeclient::Resource) }
    subject(:kpack_client) { Kubernetes::KpackClient.new(kube_client) }

    it 'fetches the image from Kubernetes' do
      allow(kube_client).to receive(:get_image).with('name', 'namespace').and_return(response)

      image = subject.get_image('name', 'namespace')
      expect(image).to eq(response)
    end

    context 'when the image is not present' do
      it 'returns nil' do
        allow(kube_client).to receive(:get_image).with('name', 'namespace').and_raise(Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

        image = subject.get_image('name', 'namespace')
        expect(image).to be_nil
      end
    end

    context 'when there is an error' do
      it 'raises as an ApiError' do
        allow(kube_client).to receive(:get_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

        expect {
          subject.get_image('name', 'namespace')
        }.to raise_error(CloudController::Errors::ApiError)
      end
    end
  end

  describe '#update_image' do
    let(:kube_client) { double(Kubeclient) }
    let(:args) { [1, 2, 'a', 'b'] }
    let(:response) { double(Kubeclient::Resource) }
    subject(:kpack_client) { Kubernetes::KpackClient.new(kube_client) }

    it 'proxies call to kubernetes client with the same args' do
      allow(kube_client).to receive(:update_image).with(any_args)

      subject.update_image(*args)

      expect(kube_client).to have_received(:update_image).with(*args).once
    end

    context 'when there is an error' do
      it 'raises as an ApiError' do
        allow(kube_client).to receive(:update_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

        expect {
          subject.update_image(*args)
        }.to raise_error(CloudController::Errors::ApiError)
      end
    end
  end
end

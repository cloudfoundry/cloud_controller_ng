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
end

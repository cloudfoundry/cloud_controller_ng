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
  end
end

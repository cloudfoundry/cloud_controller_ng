require 'lightweight_spec_helper'
require 'kubernetes/eirini_client'

RSpec.describe Kubernetes::EiriniClient do
  let(:eirini_kube_client) { double(Kubeclient::Client) }

  subject(:k8s_eirini_client) do
    Kubernetes::EiriniClient.new(
      eirini_kube_client: eirini_kube_client
    )
  end

  describe '#create_lrp' do
    let(:lrp) { double(:lrp) }

    before do
      allow(eirini_kube_client).to receive(:create_lrp)
    end

    it 'delegates to the kubeclient' do
      subject.create_lrp(lrp)
      expect(eirini_kube_client).to have_received(:create_lrp).with(lrp).once
    end

    context "when the LRP creation fails" do
      before do
        allow(eirini_kube_client).to receive(:create_lrp).and_raise(Kubeclient::HttpError.new(422, 'the-error-message', nil))
      end

      it "raises an ApiError" do
        expect { subject.create_lrp(lrp) }.to raise_error do |e|
          expect(e).to be_a(CloudController::Errors::ApiError)
          expect(e.message).to eq("Failed to create LRP resource: 'the-error-message'")
        end
      end
    end
  end
end

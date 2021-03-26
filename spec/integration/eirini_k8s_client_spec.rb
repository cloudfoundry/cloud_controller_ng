require 'spec_helper'

skip_eirini_tests = ENV['CF_RUN_EIRINI_SPECS'] != 'true'
RSpec.describe(Kubernetes::EiriniClient, type: :intgration, skip: skip_eirini_tests) do
  let(:kube_client) do
    kubeconfig = Kubeclient::Config.read(ENV['KUBECONFIG'] || "#{ENV['HOME']}/.kube/config")
    context_name = ENV['KUBE_CLUSTER_NAME']
    fail 'Please export KUBE_CLUSTER_NAME' unless context_name

    context = kubeconfig.context(context_name)

    Kubeclient::Client.new(
      "#{context.api_endpoint}/apis/eirini.cloudfoundry.org",
      'v1',
      ssl_options: context.ssl_options,
      auth_options: context.auth_options
    )
  end

  let(:lrp) do
    Kubeclient::Resource.new({
      metadata: {
        name: 'app-name',
        namespace: 'default'
      },
      spec: {
        GUID: 'process-guid',
        version: 'process-version',
        processType: 'web',
        command: ['/cnb/lifecycle/launcher', 'ls -la'],
        image: 'image1234',
        instances: 1,
        memoryMB: 128,
        cpuWeight: 1,
        diskMB: 256,
      }
    })
  end

  subject { described_class.new(eirini_kube_client: kube_client) }

  before :all do
    WebMock.allow_net_connect!
  end

  describe 'create_lrp' do
    after do
      kube_client.delete_lrp('app-name', 'default') rescue nil
    end

    it 'creates and LRP custom resource' do
      subject.create_lrp(lrp)

      created_lrp = kube_client.get_lrp('app-name', 'default')
      expect(created_lrp.metadata).to include(name: 'app-name', namespace: 'default')
      expect(created_lrp.spec).to include(
        GUID: 'process-guid',
        version: 'process-version',
        processType: 'web',
        command: ['/cnb/lifecycle/launcher', 'ls -la'],
        image: 'image1234',
        instances: 1,
        memoryMB: 128,
        cpuWeight: 1,
        diskMB: 256,
      )
    end

    context 'when a required field is missing' do
      let(:lrp) do
        Kubeclient::Resource.new({
          metadata: {
            name: 'app-name',
            namespace: 'default'
          },
          spec: {}
        })
      end

      it 'returns an error' do
        expect { subject.create_lrp(lrp) }.to raise_error do |e|
          expect(e).to be_a(CloudController::Errors::ApiError)
          expect(e.message).to match(/Failed to create LRP resource: .*: Required value/)
        end
      end
    end
  end
end

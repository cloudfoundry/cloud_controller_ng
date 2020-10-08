require 'spec_helper'

module VCAP::CloudController
  module Jobs::Kubernetes
    RSpec.describe RegistryDelete, job_context: :worker do
      let(:image_reference) { 'path/to/image' }
      let(:registry_buddy_client) { instance_double(RegistryBuddy::Client) }

      subject(:job) do
        RegistryDelete.new(image_reference)
      end

      describe '#perform' do
        it 'sends a request to the registry buddy to delete the package' do
          allow(CloudController::DependencyLocator.instance).to receive(:registry_buddy_client).
            and_return(registry_buddy_client)
          allow(registry_buddy_client).to receive(:delete_image)

          job.perform

          expect(registry_buddy_client).to have_received(:delete_image).with(image_reference)
        end
      end
    end
  end
end

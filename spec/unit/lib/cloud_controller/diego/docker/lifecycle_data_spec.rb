require 'spec_helper'
require 'cloud_controller/diego/docker/lifecycle_data'

module VCAP::CloudController
  module Diego
    module Docker
      describe LifecycleData do
        let(:lifecycle_data) do
          data = LifecycleData.new
          data.docker_image = 'docker:///image/something'
          data
        end

        let(:lifecycle_payload) do
          { docker_image: 'docker:///image/something' }
        end

        it 'populates the message' do
          expect(lifecycle_data.message).to eq(lifecycle_payload)
        end

        describe 'validation' do
          let(:optional_keys) { [:build_artifacts_cache_download_uri] }

          context 'when the docker image is missing' do
            before do
              lifecycle_data.docker_image = nil
            end

            it 'raises an error' do
              expect {
                lifecycle_data.message
              }.to raise_error(Membrane::SchemaValidationError)
            end
          end
        end
      end
    end
  end
end

require 'spec_helper'
require 'cloud_controller/diego/traditional/lifecycle_data'

module VCAP::CloudController
  module Diego
    module Traditional
      describe LifecycleData do
        let(:lifecycle_data) do
          data = LifecycleData.new
          data.app_bits_download_uri = 'app_bits_download'
          data.build_artifacts_cache_download_uri = 'build_artifact_download'
          data.build_artifacts_cache_upload_uri = 'build_artifact_upload'
          data.droplet_upload_uri = 'droplet_upload'
          data.buildpacks = []
          data.stack = 'stack'
          data
        end

        let(:lifecycle_payload) do
          {
            app_bits_download_uri: 'app_bits_download',
            build_artifacts_cache_download_uri: 'build_artifact_download',
            build_artifacts_cache_upload_uri: 'build_artifact_upload',
            droplet_upload_uri: 'droplet_upload',
            buildpacks: [],
            stack: 'stack',
          }
        end

        it 'populates the fields' do
          expect(lifecycle_data.message).to eq(lifecycle_payload)
        end

        describe 'validation' do
          let(:optional_keys) { [:build_artifacts_cache_download_uri] }

          context 'when build artifacts cache download uri is missing' do
            before do
              lifecycle_data.build_artifacts_cache_download_uri = nil
            end

            it 'does not raise an error' do
              expect {
                lifecycle_data.message
              }.to_not raise_error
            end

            it 'omits buildpack artifacts cache download uri from the message' do
              expect(lifecycle_data.message.keys).to_not include(:build_artifacts_cache_download_uri)
            end
          end

          context 'when anything else is missing' do
            let(:required_keys) { lifecycle_payload.keys - optional_keys }

            it 'fails with a schema validation error' do
              required_keys.each do |key|
                data = lifecycle_data.clone
                data.public_send("#{key}=", nil)
                expect {
                  data.message
                }.to raise_error(Membrane::SchemaValidationError)
              end
            end
          end
        end
      end
    end
  end
end

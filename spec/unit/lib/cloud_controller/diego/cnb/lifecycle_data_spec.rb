require 'spec_helper'
require 'cloud_controller/diego/buildpack/lifecycle_data'

module VCAP::CloudController
  module Diego
    module CNB
      RSpec.describe LifecycleData do
        let(:lifecycle_data) do
          data                                    = LifecycleData.new
          data.app_bits_download_uri              = 'app_bits_download'
          data.build_artifacts_cache_download_uri = 'build_artifact_download'
          data.build_artifacts_cache_upload_uri   = 'build_artifact_upload'
          data.droplet_upload_uri                 = 'droplet_upload'
          data.buildpacks                         = ['docker://docker.io/paketobuildpacks/nodejs']
          data.stack                              = 'stack'
          data.buildpack_cache_checksum           = 'bp-cache-checksum'
          data.app_bits_checksum                  = { type: 'sha256', value: 'package-checksum' }
          data.credentials                        = '{"registry":{"username":"password"}}'
          data.auto_detect                        = false
          data
        end

        let(:lifecycle_payload) do
          {
            app_bits_download_uri: 'app_bits_download',
            build_artifacts_cache_download_uri: 'build_artifact_download',
            build_artifacts_cache_upload_uri: 'build_artifact_upload',
            droplet_upload_uri: 'droplet_upload',
            buildpacks: ['docker://docker.io/paketobuildpacks/nodejs'],
            stack: 'stack',
            buildpack_cache_checksum: 'bp-cache-checksum',
            app_bits_checksum: { type: 'sha256', value: 'package-checksum' },
            credentials: '{"registry":{"username":"password"}}',
            auto_detect: false
          }
        end

        it 'populates the fields' do
          expect(lifecycle_data.message).to eq(lifecycle_payload)
        end

        describe 'validation' do
          let(:optional_keys) { %i[build_artifacts_cache_download_uri buildpack_cache_checksum credentials] }

          context 'when build artifacts cache download uri is missing' do
            before do
              lifecycle_data.build_artifacts_cache_download_uri = nil
            end

            it 'does not raise an error' do
              expect do
                lifecycle_data.message
              end.not_to raise_error
            end

            it 'omits buildpack artifacts cache download uri from the message' do
              expect(lifecycle_data.message.keys).not_to include(:build_artifacts_cache_download_uri)
            end
          end

          context 'when buildpack_cache_checksum is missing' do
            before do
              lifecycle_data.buildpack_cache_checksum = nil
            end

            it 'does not raise an error' do
              expect do
                lifecycle_data.message
              end.not_to raise_error
            end

            it 'omits buildpack_cache_checksum from the message' do
              expect(lifecycle_data.message.keys).not_to include(:buildpack_cache_checksum)
            end
          end

          context 'when credentials are missing' do
            before do
              lifecycle_data.credentials = nil
            end

            it 'does not raise an error' do
              expect do
                lifecycle_data.message
              end.not_to raise_error
            end

            it 'omits credentials from the message' do
              expect(lifecycle_data.message.keys).not_to include(:credentials)
            end
          end

          context 'when anything else is missing' do
            let(:required_keys) { lifecycle_payload.keys - optional_keys }

            it 'fails with a schema validation error' do
              required_keys.each do |key|
                data = lifecycle_data.clone
                data.public_send("#{key}=", nil)
                expect do
                  data.message
                end.to raise_error(
                  Membrane::SchemaValidationError, /{ #{key} => Expected instance of (String|Array|Hash|true or false), given .*}/
                )
              end
            end
          end
        end
      end
    end
  end
end

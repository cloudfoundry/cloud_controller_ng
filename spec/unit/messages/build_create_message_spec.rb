require 'spec_helper'
require 'messages/build_create_message'

module VCAP::CloudController
  RSpec.describe BuildCreateMessage do
    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          message = BuildCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:package_guid]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            unexpected: 'meow',
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs4' } }
          }
        end

        it 'is not valid' do
          message = BuildCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'package guid' do
        context 'when no package guid is given' do
          let(:params) do
            { package: nil }
          end

          it 'is not valid' do
            message = BuildCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:package_guid]).to include("can't be blank")
          end
        end

        context 'package guid is not a guid' do
          let(:params) do
            {
              package: { guid: 1 },
              lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs4' } }
            }
          end

          it 'is not valid' do
            message = BuildCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:package_guid]).to include('must be a string')
          end
        end
      end

      context 'lifecycle' do
        let(:params) do
          { package: { guid: 'guid' } }
        end

        context 'when lifecycle is not provided' do
          it 'is valid' do
            message = BuildCreateMessage.new(params)

            expect(message).to be_valid
          end
        end

        context 'when lifecycle is provided' do
          it 'is valid' do
            params[:lifecycle] = { type: 'buildpack', data: { buildpacks: ['java'], stack: 'cflinuxfs4' } }
            message = BuildCreateMessage.new(params)
            expect(message).to be_valid
          end

          it 'must provide type' do
            params[:lifecycle] = { data: { buildpacks: ['java'], stack: 'cflinuxfs4' } }

            message = BuildCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors[:lifecycle_type]).to include('must be a string')
          end

          it 'must be a valid lifecycle type' do
            params[:lifecycle] = { data: {}, type: { subhash: 'woah!' } }

            message = BuildCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:lifecycle_type]).to include('must be a string')
          end

          it 'must provide a data field' do
            params[:lifecycle] = { type: 'buildpack' }

            message = BuildCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:lifecycle_data]).to include('must be an object')
          end

          describe 'buildpack lifecycle' do
            it 'must provide a valid stack' do
              params[:lifecycle] = { type: 'buildpack', data: { buildpack: 'java', stack: { non: 'sense' } } }

              message = BuildCreateMessage.new(params)

              expect(message).not_to be_valid
              expect(message.errors[:lifecycle]).to include('Stack must be a string')
            end

            it 'must provide a valid buildpack' do
              params[:lifecycle] = { type: 'buildpack', data: { buildpacks: [{ wh: 'at?' }], stack: 'onstacksonstacks' } }

              message = BuildCreateMessage.new(params)

              expect(message).not_to be_valid
              expect(message.errors[:lifecycle]).to include('Buildpacks can only contain strings')
            end
          end

          describe 'docker lifecycle' do
            it 'is valid' do
              message = BuildCreateMessage.new(params)
              expect(message).to be_valid
            end

            context 'when the message includes metadata' do
              let(:all_params) { params.merge(metadata) }

              context 'when the metadata is not valid' do
                let(:metadata) do
                  {

                    'metadata' => {
                      'ladles' => {
                        'tags' => 'tureens'
                      }
                    }
                  }
                end

                it 'is not valid' do
                  message = BuildCreateMessage.new(all_params)
                  expect(message).not_to be_valid
                end
              end

              context 'when the metadata is valid' do
                let(:metadata) do
                  {

                    'metadata' => {
                      'labels' => {
                        'potatoes' => 'packagedTots'
                      }
                    }
                  }
                end

                it 'includes the metadata in the message' do
                  message = BuildCreateMessage.new(all_params)
                  expect(message).to be_valid
                  expect(message.labels).to include(potatoes: 'packagedTots')
                end
              end
            end
          end

          describe 'cnb lifecycle' do
            let(:params) do
              {
                package: { guid: 'some-guid' },
                lifecycle: { type: 'cnb', data: {} }
              }
            end

            it 'is valid' do
              message = BuildCreateMessage.new(params)
              expect(message).to be_valid
            end
          end
        end
      end
    end

    describe '#staging_memory_in_mb' do
      subject(:build_create_message) { BuildCreateMessage.new(params) }
      let(:params) { { staging_memory_in_mb: 765 } }

      it 'returns the staging_memory_in_mb' do
        expect(build_create_message.staging_memory_in_mb).to eq(765)
      end

      context 'when not provided' do
        let(:params) { nil }

        it 'returns nil' do
          expect(build_create_message.staging_memory_in_mb).to be_nil
        end
      end
    end

    describe '#staging_disk_in_mb' do
      subject(:build_create_message) { BuildCreateMessage.new(params) }
      let(:params) { { staging_disk_in_mb: 765 } }

      it 'returns the staging_disk_in_mb' do
        expect(build_create_message.staging_disk_in_mb).to eq(765)
      end

      context 'when not provided' do
        let(:params) { nil }

        it 'returns nil' do
          expect(build_create_message.staging_disk_in_mb).to be_nil
        end
      end
    end

    describe '#staging_log_rate_limit_bytes_per_second' do
      subject(:build_create_message) { BuildCreateMessage.new(params) }
      let(:params) { { staging_log_rate_limit_bytes_per_second: -1 } }

      it 'returns the staging_log_rate_limit_bytes_per_second' do
        expect(build_create_message.staging_log_rate_limit_bytes_per_second).to eq(-1)
      end

      context 'when not provided' do
        let(:params) { nil }

        it 'returns nil' do
          expect(build_create_message.staging_log_rate_limit_bytes_per_second).to be_nil
        end
      end

      context 'when the value is less than -1' do
        let(:params) do
          {
            package: { guid: 'some-guid' },
            staging_log_rate_limit_bytes_per_second: -2
          }
        end

        it 'is invalid' do
          expect(build_create_message.valid?).to be false
        end
      end

      context 'when the value is too large' do
        let(:params) do
          {
            package: { guid: 'some-guid' },
            staging_log_rate_limit_bytes_per_second: 2**63
          }
        end

        it 'is invalid' do
          expect(build_create_message.valid?).to be false
        end
      end
    end

    describe '#environment variables' do
      subject(:build_create_message) { BuildCreateMessage.new(params) }

      let(:env_vars) { { name: 'value' } }
      let(:params) { { environment_variables: env_vars } }

      it 'returns the staging_disk_in_mb' do
        expect(build_create_message.environment_variables).to eq(env_vars)
      end

      context 'when not provided' do
        let(:params) { nil }

        it 'returns nil' do
          expect(build_create_message.environment_variables).to be_nil
        end
      end
    end
  end
end

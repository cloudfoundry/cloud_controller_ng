require 'spec_helper'
require 'cloud_controller/diego/docker/lifecycle_data'

module VCAP::CloudController
  module Diego
    module Docker
      RSpec.describe LifecycleData do
        let(:image) { 'docker:///image/something' }
        let(:login_server) { 'http://loginServer.com' }
        let(:user) { 'user' }
        let(:password) { 'password' }
        let(:email) { 'email@example.com' }

        let(:lifecycle_data) do
          data = LifecycleData.new
          data.docker_image = image
          data.docker_login_server = login_server
          data.docker_user = user
          data.docker_password = password
          data.docker_email = email
          data
        end

        describe '#message' do
          let(:lifecycle_payload) do
            {
              docker_image: image,
              docker_login_server: login_server,
              docker_user: user,
              docker_password: password,
              docker_email: email
            }
          end

          it 'populates the message' do
            expect(lifecycle_data.message).to eq(lifecycle_payload)
          end

          context 'empty optional field' do
            let(:lifecycle_payload) do
              { docker_image: image }
            end

            before do
              lifecycle_data.docker_login_server = nil
              lifecycle_data.docker_user = ''
              lifecycle_data.docker_password = nil
              lifecycle_data.docker_email = '   '
            end

            it 'is not included in the message' do
              expect(lifecycle_data.message).to eq(lifecycle_payload)
            end
          end
        end

        describe 'validation' do
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

          context 'when optional arguments are missing' do
            before do
              lifecycle_data.docker_login_server = nil
              lifecycle_data.docker_user = ''
              lifecycle_data.docker_password = nil
              lifecycle_data.docker_email = '   '
            end

            it 'does not raise an error' do
              expect {
                lifecycle_data.message
              }.not_to raise_error
            end
          end
        end
      end
    end
  end
end

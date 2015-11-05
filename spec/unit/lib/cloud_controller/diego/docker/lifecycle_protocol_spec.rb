require 'spec_helper'
require_relative '../lifecycle_protocol_shared'

module VCAP
  module CloudController
    module Diego
      module Docker
        describe LifecycleProtocol do
          let(:lifecycle_protocol) { LifecycleProtocol.new }

          it_behaves_like 'a lifecycle protocol' do
            let(:app) { App.make(docker_image: 'https://cool.image') }
          end

          describe '#lifecycle_data' do
            let(:app) { AppFactory.make(docker_image: 'fake/docker_image') }

            it 'returns lifecycle data of type docker' do
              type = lifecycle_protocol.lifecycle_data(app)[0]
              expect(type).to eq('docker')
            end

            it 'sets the docker image' do
              message = lifecycle_protocol.lifecycle_data(app)[1]
              expect(message[:docker_image]).to eq(app.docker_image)
            end

            context 'when there are image credentials' do
              let(:server) { 'http://loginServer.com' }
              let(:user) { 'user' }
              let(:password) { 'password' }
              let(:email) { 'email' }
              let(:docker_credentials) do
                {
                  docker_login_server: server,
                  docker_user: user,
                  docker_password: password,
                  docker_email: email
                }
              end
              let(:app) { AppFactory.make(docker_image: 'fake/docker_image', docker_credentials_json: docker_credentials, diego: true) }

              it 'uses the provided credentials to stage a Docker app' do
                message = lifecycle_protocol.lifecycle_data(app)[1]

                expect(message[:docker_login_server]).to eq(server)
                expect(message[:docker_user]).to eq(user)
                expect(message[:docker_password]).to eq(password)
                expect(message[:docker_email]).to eq(email)
              end
            end
          end

          describe '#desired_app_message' do
            let(:app) { AppFactory.make(docker_image: 'cloudfoundry/diego-docker-app:latest', diego: true) }

            it 'sets the start command' do
              message = lifecycle_protocol.desired_app_message(app)
              expect(message['start_command']).to eq(app.command)
            end

            describe 'setting the docker image' do
              context 'when there is no current_droplet for app' do
                let(:docker_image) { 'cloudfoundry/diego-docker-app:latest' }
                let(:app) do
                  App.make(
                    name: Sham.name,
                    space: Space.make,
                    stack: Stack.default,
                    docker_image: docker_image,
                    diego: true
                  )
                end

                it 'uses the user provided docker image' do
                  message = lifecycle_protocol.desired_app_message(app)
                  expect(message['docker_image']).to eq(docker_image)
                end
              end

              context 'when there is a cached_docker_image' do
                let(:cached_docker_image) { '10.244.2.6:8080/uuid' }

                before { app.current_droplet.cached_docker_image = cached_docker_image }

                it 'uses the cached_docker_image instead of the user provided' do
                  message = lifecycle_protocol.desired_app_message(app)
                  expect(message['docker_image']).to eq(cached_docker_image)
                end
              end
            end
          end
        end
      end
    end
  end
end

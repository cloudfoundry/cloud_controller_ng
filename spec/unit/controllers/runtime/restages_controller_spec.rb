require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RestagesController do
    let(:app_event_repository) { Repositories::AppEventRepository.new }
    before { CloudController::DependencyLocator.instance.register(:app_event_repository, app_event_repository) }

    describe 'POST /v2/apps/:id/restage' do
      let!(:application) { AppFactory.make }

      subject(:restage_request) { post "/v2/apps/#{application.guid}/restage", {} }

      before do
        set_current_user(account)
      end

      context 'as a user' do
        let(:account) { make_user_for_space(application.space) }

        it 'should return 403' do
          restage_request
          expect(last_response.status).to eq(403)
        end
      end

      context 'as a developer' do
        let(:account) { make_developer_for_space(application.space) }
        let(:app_stage) { instance_double(V2::AppStage, stage: nil) }

        before do
          allow(V2::AppStage).to receive(:new).and_return(app_stage)
        end

        it 'removes the current droplet from the app' do
          expect(application.current_droplet).not_to be_nil

          restage_request
          expect(last_response.status).to eq(201)

          expect(application.reload.current_droplet).to be_nil
        end

        it 'restages the app' do
          restage_request
          expect(last_response.status).to eq(201)
          expect(app_stage).to have_received(:stage).with(application)
        end

        it 'returns the application' do
          restage_request
          expect(last_response.body).to match('v2/apps')
          expect(last_response.body).to match(application.guid)
        end

        context 'when the app is pending to be staged' do
          before do
            PackageModel.make(app: application.app)
            application.reload
          end

          it "returns '170002 NotStaged'" do
            restage_request

            expect(last_response.status).to eq(400)
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['code']).to eq(170002)
          end
        end

        context 'with a Docker app' do
          before do
            FeatureFlag.create(name: 'diego_docker', enabled: true)
          end

          let!(:docker_app) { AppFactory.make(docker_image: 'some-image') }

          subject(:restage_request) { post("/v2/apps/#{docker_app.guid}/restage", {}) }

          context 'when there are validation errors' do
            before do
              allow_any_instance_of(VCAP::CloudController::RestagesController).to receive(:find_guid_and_validate_access).with(:read, docker_app.guid).and_return(docker_app)
            end

            context 'when Docker is disabled' do
              before do
                FeatureFlag.find(name: 'diego_docker').update(enabled: false)
              end

              it 'correctly propagates the error' do
                restage_request

                expect(last_response.status).to eq(400)
                expect(decoded_response['code']).to eq(320003)
                expect(decoded_response['description']).to match(/Docker support has not been enabled./)
              end
            end
          end
        end

        describe 'events' do
          before do
            allow(app_event_repository).to receive(:record_app_restage).and_call_original
          end

          context 'when the restage completes without error' do
            it 'generates an audit.app.restage event' do
              expect {
                restage_request
              }.to change { Event.count }.by(1)

              expect(last_response.status).to eq(201)
              expect(app_event_repository).to have_received(:record_app_restage).with(application, account.guid, SecurityContext.current_user_email)
            end
          end

          context 'when the restage fails due to an error' do
            before do
              allow(app_stage).to receive(:stage).and_raise('Error staging')
            end

            it 'does not generate an audit.app.restage event' do
              restage_request

              expect(last_response.status).to eq(500)
              expect(app_event_repository).to_not have_received(:record_app_restage)
            end
          end
        end

        context 'when the app has a staged droplet but no package' do
          before do
            application.latest_package.destroy
          end

          it 'raises error' do
            restage_request

            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('bits have not been uploaded')
          end
        end
      end
    end
  end
end

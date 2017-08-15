require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RestagesController do
    let(:app_event_repository) { Repositories::AppEventRepository.new }
    before { CloudController::DependencyLocator.instance.register(:app_event_repository, app_event_repository) }

    describe 'POST /v2/apps/:id/restage' do
      subject(:restage_request) { post "/v2/apps/#{process.guid}/restage", {} }
      let!(:process) { ProcessModelFactory.make }
      let(:app_stage) { instance_double(V2::AppStage, stage: nil) }

      before do
        allow(V2::AppStage).to receive(:new).and_return(app_stage)
      end

      before do
        set_current_user(account)
      end

      context 'as a user' do
        let(:account) { make_user_for_space(process.space) }

        it 'should return 403' do
          restage_request
          expect(last_response.status).to eq(403)
        end
      end

      context 'as a space auditor' do
        let(:account) { make_auditor_for_space(process.space) }

        it 'should return 403' do
          restage_request
          expect(last_response.status).to eq(403)
        end
      end

      context 'as a developer' do
        let(:account) { make_developer_for_space(process.space) }

        it 'removes the current droplet from the app' do
          expect(process.current_droplet).not_to be_nil

          restage_request
          expect(last_response.status).to eq(201)

          expect(process.reload.current_droplet).to be_nil
        end

        it 'restages the app' do
          restage_request
          expect(last_response.status).to eq(201)
          expect(app_stage).to have_received(:stage).with(process)
        end

        it 'returns the process' do
          restage_request
          expect(last_response.body).to match('v2/apps')
          expect(last_response.body).to match(process.guid)
        end

        context 'when the app is pending to be staged' do
          before do
            PackageModel.make(app: process.app)
            process.reload
          end

          it "returns '170002 NotStaged'" do
            restage_request

            expect(last_response.status).to eq(400)
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['code']).to eq(170002)
          end
        end

        context 'when the process does not exist' do
          subject(:restage_request) { post '/v2/apps/blub-blub-blub/restage', {} }

          it '404s' do
            restage_request

            expect(last_response.status).to eq(404)
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['code']).to eq(100004)
            expect(parsed_response['description']).to eq('The app could not be found: blub-blub-blub')
          end
        end

        context 'when the web process has 0 instances' do
          let!(:process) { ProcessModelFactory.make(type: 'web', instances: 0) }

          before do
            process.reload
          end

          it 'errors because web must have > 0 instances' do
            restage_request

            expect(last_response.status).to eq(400)
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['code']).to eq(170001)
            expect(parsed_response['description']).to eq('Staging error: App must have at least 1 instance to stage.')
          end
        end

        context 'when calling with a non-web process guid' do
          let!(:web_process) { ProcessModelFactory.make(type: 'web', instances: 1) }
          let!(:process) { ProcessModelFactory.make(type: 'foobar', instances: 1) }

          before do
            process.reload
          end

          it '404s because restage only works for web processes' do
            restage_request

            expect(last_response.status).to eq(404)
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['code']).to eq(100004)
            expect(parsed_response['description']).to match(/The app could not be found:/)
          end
        end

        context 'with a Docker app' do
          let!(:process) { ProcessModelFactory.make(docker_image: 'some-image') }

          before do
            FeatureFlag.create(name: 'diego_docker', enabled: true)
          end

          context 'when there are validation errors' do
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
            let(:user_audit_info) { UserAuditInfo.from_context(SecurityContext) }
            before do
              allow(UserAuditInfo).to receive(:from_context).and_return(user_audit_info)
            end

            it 'generates an audit.app.restage event' do
              expect {
                restage_request
              }.to change { Event.count }.by(1)

              expect(last_response.status).to eq(201)
              expect(app_event_repository).to have_received(:record_app_restage).with(process,
                user_audit_info)
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
            process.latest_package.destroy
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

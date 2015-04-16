require 'spec_helper'

module VCAP::CloudController
  describe RestagesController do
    let(:app_event_repository) { Repositories::Runtime::AppEventRepository.new }
    before { CloudController::DependencyLocator.instance.register(:app_event_repository, app_event_repository) }

    describe 'POST /v2/apps/:id/restage' do
      let(:package_state) { 'STAGED' }
      let!(:application) { AppFactory.make(package_hash: 'abc', package_state: package_state) }

      subject(:restage_request) { post("/v2/apps/#{application.guid}/restage", {}, headers_for(account)) }

      context 'as a user' do
        let(:account) { make_user_for_space(application.space) }

        it 'should return 403' do
          restage_request
          expect(last_response.status).to eq(403)
        end
      end

      context 'as a developer' do
        let(:account) { make_developer_for_space(application.space) }

        it 'restages the app' do
          allow_any_instance_of(VCAP::CloudController::RestagesController).to receive(:find_guid_and_validate_access).with(:read, application.guid).and_return(application)

          allow(application).to receive(:restage!)
          restage_request

          expect(last_response.status).to eq(201)
          expect(application).to have_received(:restage!)
        end

        it 'returns the application' do
          restage_request
          expect(last_response.body).to match('v2/apps')
          expect(last_response.body).to match(application.guid)
        end

        context 'when the app is pending to be staged' do
          before do
            application.package_state = 'PENDING'
            application.save
          end

          it "returns '170002 NotStaged'" do
            restage_request

            expect(last_response.status).to eq(400)
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['code']).to eq(170002)
          end
        end

        describe 'events' do
          before do
            allow(app_event_repository).to receive(:record_app_restage).and_call_original
          end

          context 'when the restage completes without error' do
            it 'generates an audit.app.restage event' do
              restage_request

              expect(last_response.status).to eq(201)
              expect(app_event_repository).to have_received(:record_app_restage).with(application, account.guid, SecurityContext.current_user_email)
            end
          end

          context 'when the restage fails due to an error' do
            before do
              allow_any_instance_of(App).to receive(:restage!).and_raise('Error saving')
            end

            it 'does not generate an audit.app.restage event' do
              restage_request

              expect(last_response.status).to eq(500)
              expect(app_event_repository).to_not have_received(:record_app_restage)
            end
          end
        end
      end
    end
  end
end

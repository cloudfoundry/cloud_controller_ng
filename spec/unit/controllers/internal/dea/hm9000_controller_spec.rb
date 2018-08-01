require 'spec_helper'
require 'membrane'

module VCAP::CloudController
  module Dea
    RSpec.describe HM9000Controller do
      let(:respondent) { instance_double(HM9000::Respondent, process_hm9000_stop: nil, process_hm9000_start: nil) }

      def make_dea_app(app_state)
        AppFactory.make.tap do |app|
          app.state = app_state
          app.save
        end
      end

      before do
        allow(SubSystem).to receive(:hm9000_respondent).and_return(respondent)

        @internal_user = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
      end

      describe 'stop' do
        let(:v2_app) { make_dea_app('STARTED') }
        let(:app_guid) { v2_app.guid }
        let(:url) { "/internal/dea/hm9000/stop/#{app_guid}" }

        let(:stop_message) {
          {
            'droplet' => app_guid,
            'version' => '1',
            'instance_guid' => 'heebity',
            'instance_index' => '0',
            'is_duplicate' => false,
          }
        }
        context 'authentication' do
          context 'when missing authentication' do
            it 'fails with authentication required' do
              header('Authorization', nil)
              post url, MultiJson.dump(stop_message)
              expect(last_response.status).to eq(401)
            end
          end

          context 'when using invalid credentials' do
            it 'fails with authenticatiom required' do
              authorize 'bar', 'foo'
              post url, MultiJson.dump(stop_message)
              expect(last_response.status).to eq(401)
            end
          end

          context 'when using valid credentials' do
            before do
              allow_any_instance_of(Dea::Stager).to receive(:staging_complete)
            end

            it 'succeeds' do
              post url, MultiJson.dump(stop_message)
              expect(last_response.status).to eq(200)
            end
          end
        end

        context 'validation' do
          context 'when sending invalid json' do
            it 'fails with a 400' do
              post url, 'this is not json'

              expect(last_response.status).to eq(400)
              expect(last_response.body).to match /MessageParseError/
            end
          end
        end

        context 'when the app does not exist' do
          before { v2_app.delete }

          it 'fails with a 404' do
            post url, MultiJson.dump(stop_message)

            expect(last_response.status).to eq(404)
          end
        end

        context 'with a valid app' do
          it 'returns a 200 and calls the respondent' do
            expect(respondent).to receive(:process_hm9000_stop).with(stop_message)

            post url, MultiJson.dump(stop_message)

            expect(last_response.status).to eq(200)
          end
        end
      end
      describe 'start' do
        let(:v2_app) { make_dea_app('STOPPED') }
        let(:app_guid) { v2_app.guid }
        let(:url) { "/internal/dea/hm9000/start/#{app_guid}" }

        let(:start_message) {
          {
            'droplet' => app_guid,
            'version' => '1',
            'instance_index' => '0',
          }
        }
        context 'authentication' do
          context 'when missing authentication' do
            it 'fails with authentication required' do
              header('Authorization', nil)
              post url, MultiJson.dump(start_message)
              expect(last_response.status).to eq(401)
            end
          end

          context 'when using invalid credentials' do
            it 'fails with authenticatiom required' do
              authorize 'bar', 'foo'
              post url, MultiJson.dump(start_message)
              expect(last_response.status).to eq(401)
            end
          end

          context 'when using valid credentials' do
            let(:app_starter_task) { instance_double(AppStarterTask, start: nil) }
            before do
              allow(AppStarterTask).to receive(:new).and_return(app_starter_task)
            end

            it 'succeeds' do
              post url, MultiJson.dump(start_message)
              expect(last_response.status).to eq(200)
            end
          end
        end

        context 'validation' do
          context 'when sending invalid json' do
            it 'fails with a 400' do
              post url, 'this is not json'

              expect(last_response.status).to eq(400)
              expect(last_response.body).to match /MessageParseError/
            end
          end
        end

        context 'when the app does not exist' do
          before { v2_app.delete }

          it 'fails with a 404' do
            post url, MultiJson.dump(start_message)

            expect(last_response.status).to eq(404)
          end
        end

        context 'with a valid app' do
          it 'returns a 200 and calls the respondent' do
            expect(respondent).to receive(:process_hm9000_start).with(start_message)

            post url, MultiJson.dump(start_message)

            expect(last_response.status).to eq(200)
          end
        end
      end
    end
  end
end

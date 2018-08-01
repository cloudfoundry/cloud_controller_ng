require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SyslogDrainUrlsController do
    let(:bulk_user) { 'bulk_user' }
    let(:bulk_password) { 'bulk_password' }
    let(:app_obj) { AppModel.make }
    let(:instance1) { UserProvidedServiceInstance.make(space: app_obj.space) }
    let(:instance2) { UserProvidedServiceInstance.make(space: app_obj.space) }
    let!(:binding_with_drain1) { ServiceBinding.make(syslog_drain_url: 'fishfinger', app: app_obj, service_instance: instance1) }
    let!(:binding_with_drain2) { ServiceBinding.make(syslog_drain_url: 'foobar', app: app_obj, service_instance: instance2) }

    before do
      TestConfig.config[:bulk_api][:auth_user] = bulk_user
      TestConfig.config[:bulk_api][:auth_password] = bulk_password
    end

    describe 'GET /v2/syslog_drain_urls' do
      it 'requires admin authentication' do
        get '/v2/syslog_drain_urls'
        expect(last_response.status).to eq(401)

        authorize 'bar', 'foo'
        get '/v2/syslog_drain_urls'
        expect(last_response.status).to eq(401)
      end

      describe 'when the user is authenticated' do
        before do
          authorize bulk_user, bulk_password
        end

        it 'returns a list of syslog drain urls' do
          get '/v2/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(1)
          expect(decoded_results).to include(
            {
              app_obj.guid => match_array(['fishfinger', 'foobar']),
            }
          )
        end

        context 'when an app has no service binding' do
          let!(:app_no_binding) { AppModel.make }

          it 'does not include that app' do
            get '/v2/syslog_drain_urls', '{}'
            expect(last_response).to be_successful
            expect(decoded_results).not_to have_key(app_no_binding.guid)
          end
        end

        context "when an app's bindings have no syslog_drain_url" do
          let!(:app_no_drain) { ServiceBinding.make.app }

          it 'does not include that app' do
            get '/v2/syslog_drain_urls', '{}'
            expect(last_response).to be_successful
            expect(decoded_results).not_to have_key(app_no_drain.guid)
          end
        end

        context "when an app's binding has blank syslog_drain_urls" do
          let!(:app_empty_drain) { ServiceBinding.make(syslog_drain_url: '').app }

          it 'includes the app without the empty syslog_drain_urls' do
            get '/v2/syslog_drain_urls', '{}'
            expect(last_response).to be_successful
            expect(decoded_results).not_to have_key(app_empty_drain.guid)
          end
        end

        def decoded_results
          decoded_response.fetch('results')
        end

        describe 'paging' do
          before do
            3.times do
              app_obj = AppModel.make
              instance = UserProvidedServiceInstance.make(space: app_obj.space)
              ServiceBinding.make(syslog_drain_url: 'fishfinger', app: app_obj, service_instance: instance)
            end
          end

          it 'respects the batch_size parameter' do
            [1, 3].each do |size|
              get '/v2/syslog_drain_urls', { 'batch_size' => size }
              expect(last_response).to be_successful
              expect(decoded_results.size).to eq(size)
            end
          end

          it 'returns non-intersecting results when token is supplied' do
            get '/v2/syslog_drain_urls', {
              'batch_size' => 2,
              'next_id' => 0
            }

            saved_results = decoded_response['results'].dup
            expect(saved_results.size).to eq(2)

            get '/v2/syslog_drain_urls', {
              'batch_size' => 2,
              'next_id' => decoded_response['next_id'],
            }

            new_results = decoded_response['results'].dup

            expect(new_results.size).to eq(2)
            saved_results.each do |guid, drains|
              expect(new_results).not_to have_key(guid)
            end
          end

          it 'should eventually return entire collection, batch after batch' do
            apps = {}
            total_size = AppModel.count

            token = 0
            while apps.size < total_size
              get '/v2/syslog_drain_urls', {
                'batch_size' => 2,
                'next_id' => token,
              }

              expect(last_response.status).to eq(200)
              token = decoded_response['next_id']
              apps.merge!(decoded_response['results'])
            end

            expect(apps.size).to eq(total_size)
            get '/v2/syslog_drain_urls', {
              'batch_size' => 2,
              'next_id' => token,
            }
            expect(decoded_response['results'].size).to eq(0)
            expect(decoded_response['next_id']).to be_nil
          end

          context 'when an app has no service_bindings' do
            before do
              AppModel.make(guid: '00000')
            end

            it 'does not affect the paging results' do
              get '/v2/syslog_drain_urls', {
                'batch_size' => 2,
                'next_id' => 0
              }

              saved_results = decoded_response['results'].dup
              expect(saved_results.size).to eq(2)
            end
          end

          context 'when an app has no syslog_drain_urls' do
            let(:app_with_first_ordered_guid) { AppModel.make(guid: '000', space: instance1.space) }
            before do
              ServiceBinding.make(syslog_drain_url: nil, app: app_with_first_ordered_guid, service_instance: instance1)
            end

            it 'does not affect the paging results' do
              get '/v2/syslog_drain_urls', {
                'batch_size' => 2,
                'next_id' => 0
              }

              saved_results = decoded_response['results'].dup
              expect(saved_results.size).to eq(2)
            end
          end
        end
      end
    end
  end
end

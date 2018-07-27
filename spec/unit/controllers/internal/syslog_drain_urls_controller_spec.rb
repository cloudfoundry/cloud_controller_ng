require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SyslogDrainUrlsInternalController do
    let(:org) { Organization.make(name: 'org-1') }
    let(:space) { Space.make(name: 'space-1', organization: org) }
    let(:app_obj) { AppModel.make(name: 'app-1', space: space) }
    let(:instance1) { UserProvidedServiceInstance.make(space: app_obj.space) }
    let(:instance2) { UserProvidedServiceInstance.make(space: app_obj.space) }
    let!(:binding_with_drain1) { ServiceBinding.make(syslog_drain_url: 'fishfinger', app: app_obj, service_instance: instance1) }
    let!(:binding_with_drain2) { ServiceBinding.make(syslog_drain_url: 'foobar', app: app_obj, service_instance: instance2) }

    describe 'GET /internal/v4/syslog_drain_urls' do
      it 'returns a list of syslog drain urls' do
        get '/internal/v4/syslog_drain_urls', '{}'
        expect(last_response).to be_successful
        expect(decoded_results.count).to eq(1)
        expect(decoded_results).to include(
          {
            app_obj.guid => { 'drains'   => match_array(['fishfinger', 'foobar']),
                              'hostname' => 'org-1.space-1.app-1' }
          }
        )
      end

      context 'rfc-1034-compliance: whitespace converted to hyphens' do
        let(:org) { Organization.make(name: 'org 2') }
        let(:space) { Space.make(name: 'space 2', organization: org) }
        let(:app_obj) { AppModel.make(name: 'app 2', space: space) }

        it 'truncates trailing hyphens' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(1)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fishfinger', 'foobar']),
                                'hostname' => 'org-2.space-2.app-2' }
            }
          )
        end
      end

      context 'rfc-1034-compliance: named end with hyphens' do
        let(:org) { Organization.make(name: 'org-3-') }
        let(:space) { Space.make(name: 'space-3--', organization: org) }
        let(:app_obj) { AppModel.make(name: 'app-3---', space: space) }

        it 'truncates trailing hyphens' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(1)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fishfinger', 'foobar']),
                                'hostname' => 'org-3.space-3.app-3' }
            }
          )
        end
      end

      context 'rfc-1034-compliance: remove disallowed characters' do
        let(:org) { Organization.make(name: '!org@-4#' + [233].pack('U')) }
        let(:space) { Space.make(name: '$space%-^4--&', organization: org) }
        let(:app_obj) { AppModel.make(name: '";*app(-)4_-=-+-[]{}\\|;:,.<>/?`~', space: space) }

        it 'truncates trailing hyphens' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(1)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fishfinger', 'foobar']),
                                'hostname' => 'org-4.space-4.app-4' }
            }
          )
        end
      end

      context 'rfc-1034-compliance: truncate overlong name components to first 63' do
        let(:orgName) { 'org-5-' + 'x' * (63 - 6) }
        let(:orgNamePlus) { orgName + 'y' }
        let(:org) { Organization.make(name: orgNamePlus) }
        let(:spaceName) { 'space-5-' + 'x' * (63 - 8) }
        let(:spaceNamePlus) { spaceName + 'y' }
        let(:space) { Space.make(name: spaceNamePlus, organization: org) }
        let(:appName) { 'app-5-' + 'x' * (63 - 6) }
        let(:appNamePlus) { appName + 'y' }
        let(:app_obj) { AppModel.make(name: appNamePlus, space: space) }

        it 'truncates trailing hyphens' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(1)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fishfinger', 'foobar']),
                                'hostname' => "#{orgName}.#{spaceName}.#{appName}"
              }
            }
          )
        end
      end

      context 'rfc-1034-compliance: keep 63-char names' do
        let(:orgName) { 'org-5-' + 'x' * (63 - 6) }
        let(:org) { Organization.make(name: orgName) }
        let(:spaceName) { 'space-5-' + 'x' * (63 - 8) }
        let(:space) { Space.make(name: spaceName, organization: org) }
        let(:appName) { 'app-5-' + 'x' * (63 - 6) }
        let(:app_obj) { AppModel.make(name: appName, space: space) }

        it 'retains length-compliant names' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(1)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fishfinger', 'foobar']),
                                'hostname' => "#{orgName}.#{spaceName}.#{appName}"
              }
            }
          )
        end
      end

      context 'when an app has no service binding' do
        let!(:app_no_binding) { AppModel.make }

        it 'does not include that app' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results).not_to have_key(app_no_binding.guid)
        end
      end

      context "when an app's bindings have no syslog_drain_url" do
        let!(:app_no_drain) { ServiceBinding.make.app }

        it 'does not include that app' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results).not_to have_key(app_no_drain.guid)
        end
      end

      context "when an app's binding has blank syslog_drain_urls" do
        let!(:app_empty_drain) { ServiceBinding.make(syslog_drain_url: '').app }

        it 'includes the app without the empty syslog_drain_urls' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results).not_to have_key(app_empty_drain.guid)
        end
      end

      context 'when there are many service bindings on a single app' do
        before do
          50.times do |i|
            ServiceBinding.make(
              app: app_obj,
              syslog_drain_url: "syslog://example.com/#{i}",
              service_instance: UserProvidedServiceInstance.make(space: app_obj.space),
            )
          end
        end

        it 'includes all of the syslog_drain_urls for that app' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results[app_obj.guid]['drains'].length).to eq(52)
        end
      end

      def decoded_results
        decoded_response.fetch('results')
      end

      describe 'paging' do
        before do
          3.times do
            app_obj  = AppModel.make
            instance = UserProvidedServiceInstance.make(space: app_obj.space)
            ServiceBinding.make(syslog_drain_url: 'fishfinger', app: app_obj, service_instance: instance)
          end
        end

        it 'respects the batch_size parameter' do
          [1, 3].each do |size|
            get '/internal/v4/syslog_drain_urls', { 'batch_size' => size }
            expect(last_response).to be_successful
            expect(decoded_results.size).to eq(size)
          end
        end

        it 'returns non-intersecting results when token is supplied' do
          get '/internal/v4/syslog_drain_urls', {
            'batch_size' => 2,
            'next_id'    => 0
          }

          saved_results = decoded_results.dup
          expect(saved_results.size).to eq(2)

          get '/internal/v4/syslog_drain_urls', {
            'batch_size' => 2,
            'next_id'    => decoded_response['next_id'],
          }

          new_results = decoded_results.dup

          expect(new_results.size).to eq(2)
          saved_results.each_key do |guid|
            expect(new_results).not_to have_key(guid)
          end
        end

        it 'should eventually return entire collection, batch after batch' do
          apps       = {}
          total_size = AppModel.count

          token = 0
          while apps.size < total_size
            get '/internal/v4/syslog_drain_urls', {
              'batch_size' => 2,
              'next_id'    => token,
            }

            expect(last_response.status).to eq(200)
            token = decoded_response['next_id']
            apps.merge!(decoded_results)
          end

          expect(apps.size).to eq(total_size)
          get '/internal/v4/syslog_drain_urls', {
            'batch_size' => 2,
            'next_id'    => token,
          }
          expect(decoded_results.size).to eq(0)
          expect(decoded_response['next_id']).to be_nil
        end

        context 'when an app has no service_bindings' do
          before do
            AppModel.make(guid: '00000')
          end

          it 'does not affect the paging results' do
            get '/internal/v4/syslog_drain_urls', {
              'batch_size' => 2,
              'next_id'    => 0
            }

            saved_results = decoded_results.dup
            expect(saved_results.size).to eq(2)
          end
        end

        context 'when an app has no syslog_drain_urls' do
          let(:app_with_first_ordered_guid) { AppModel.make(guid: '000', space: instance1.space) }
          before do
            ServiceBinding.make(syslog_drain_url: nil, app: app_with_first_ordered_guid, service_instance: instance1)
          end

          it 'does not affect the paging results' do
            get '/internal/v4/syslog_drain_urls', {
              'batch_size' => 2,
              'next_id'    => 0
            }

            saved_results = decoded_results.dup
            expect(saved_results.size).to eq(2)
          end
        end
      end
    end
  end
end

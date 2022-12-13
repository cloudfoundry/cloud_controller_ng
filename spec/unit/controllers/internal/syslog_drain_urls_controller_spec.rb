require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe SyslogDrainUrlsInternalController do
    let(:org) { Organization.make(name: 'org-1') }
    let(:space) { Space.make(name: 'space-1', organization: org) }
    let(:app_obj) { AppModel.make(name: 'app-1', space: space) }
    let(:instance1) { UserProvidedServiceInstance.make(space: app_obj.space) }
    let(:instance2) { UserProvidedServiceInstance.make(space: app_obj.space) }
    let!(:binding_with_drain1) { ServiceBinding.make(syslog_drain_url: 'fish,finger', app: app_obj, service_instance: instance1) }
    let!(:binding_with_drain2) { ServiceBinding.make(syslog_drain_url: 'foobar', app: app_obj, service_instance: instance2) }

    describe 'GET /internal/v4/syslog_drain_urls' do
      it 'returns a list of syslog drain urls' do
        get '/internal/v4/syslog_drain_urls', '{}'
        expect(last_response).to be_successful
        expect(decoded_results.count).to eq(1)
        expect(decoded_v5_available).to eq(true)
        expect(decoded_results).to include(
          {
            app_obj.guid => { 'drains'   => match_array(['fish%2cfinger', 'foobar']),
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
          expect(decoded_v5_available).to eq(true)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fish%2cfinger', 'foobar']),
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
          expect(decoded_v5_available).to eq(true)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fish%2cfinger', 'foobar']),
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
          expect(decoded_v5_available).to eq(true)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fish%2cfinger', 'foobar']),
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
          expect(decoded_v5_available).to eq(true)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fish%2cfinger', 'foobar']),
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
          expect(decoded_v5_available).to eq(true)
          expect(decoded_results).to include(
            {
              app_obj.guid => { 'drains'   => match_array(['fish%2cfinger', 'foobar']),
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
          expect(decoded_v5_available).to eq(true)
          expect(decoded_results).not_to have_key(app_no_binding.guid)
        end
      end

      context "when an app's bindings have no syslog_drain_url" do
        let!(:app_no_drain) { ServiceBinding.make.app }

        it 'does not include that app' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_v5_available).to eq(true)
          expect(decoded_results).not_to have_key(app_no_drain.guid)
        end
      end

      context "when an app's binding has blank syslog_drain_urls" do
        let!(:app_empty_drain) { ServiceBinding.make(syslog_drain_url: '').app }

        it 'includes the app without the empty syslog_drain_urls' do
          get '/internal/v4/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_v5_available).to eq(true)
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
          expect(decoded_v5_available).to eq(true)
          expect(decoded_results[app_obj.guid]['drains'].length).to eq(52)
        end
      end

      describe 'paging' do
        before do
          3.times do
            app_obj  = AppModel.make
            instance = UserProvidedServiceInstance.make(space: app_obj.space)
            ServiceBinding.make(syslog_drain_url: 'fish,finger', app: app_obj, service_instance: instance)
          end
        end

        it 'respects the batch_size parameter' do
          [1, 3].each do |size|
            get '/internal/v4/syslog_drain_urls', { 'batch_size' => size }
            expect(last_response).to be_successful
            expect(decoded_v5_available).to eq(true)
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
          expect(decoded_v5_available).to eq(true)
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
            expect(decoded_v5_available).to eq(true)
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
            expect(decoded_v5_available).to eq(true)
          end
        end
      end
    end

    describe 'GET /internal/v5/syslog_drain_urls' do
      let(:app_obj2) { AppModel.make(name: 'app-2', space: space) }
      let(:app_obj3) { AppModel.make(name: 'app-3', space: space) }
      let(:app_obj4) { AppModel.make(name: 'app-4', space: space) }
      let(:instance3) { UserProvidedServiceInstance.make(space: app_obj2.space) }
      let(:instance4) { UserProvidedServiceInstance.make(space: app_obj3.space) }
      let(:instance5) { UserProvidedServiceInstance.make(space: app_obj3.space) }
      let(:instance6) { UserProvidedServiceInstance.make(space: app_obj4.space) }
      let(:instance7) { UserProvidedServiceInstance.make(space: app_obj.space) }
      let(:instance8) { UserProvidedServiceInstance.make(space: app_obj2.space) }
      let(:instance9) { UserProvidedServiceInstance.make(space: app_obj3.space) }
      let(:instance10) { UserProvidedServiceInstance.make(space: app_obj4.space) }
      let(:instance11) { UserProvidedServiceInstance.make(space: app_obj.space) }
      let!(:binding_with_drain3) { ServiceBinding.make(syslog_drain_url: 'foobar', app: app_obj2, service_instance: instance3) }
      let!(:binding_with_drain4) { ServiceBinding.make(
        syslog_drain_url: 'barfoo',
        app: app_obj3,
        service_instance: instance4,
        credentials: { 'cert' => 'cert1', 'key' => 'key1', 'ca' => 'ca1' })
      }
      let!(:binding_with_drain5) { ServiceBinding.make(
        syslog_drain_url: 'barfoo2',
        app: app_obj,
        service_instance: instance7,
        credentials: { 'cert' => 'cert1', 'key' => 'key1', 'ca' => 'ca1' })
      }
      let!(:binding_with_drain6) { ServiceBinding.make(
        syslog_drain_url: 'barfoo2',
        app: app_obj2,
        service_instance: instance8,
        credentials: { 'cert' => 'cert1', 'key' => 'key1', 'ca' => 'ca1' })
      }
      let!(:binding_with_drain7) { ServiceBinding.make(
        syslog_drain_url: 'barfoo2',
        app: app_obj3,
        service_instance: instance5,
        credentials: { 'cert' => 'cert2', 'key' => 'key2', 'ca' => 'ca2' })
      }
      let!(:binding_with_drain8) { ServiceBinding.make(
        syslog_drain_url: 'barfoo2',
        app: app_obj4,
        service_instance: instance6,
        credentials: { 'cert' => 'cert2', 'key' => 'key2', 'ca' => 'ca2' })
      }
      let!(:binding_with_drain9) { ServiceBinding.make(
        syslog_drain_url: 'no_credentials_1',
        app: app_obj3,
        service_instance: instance9,
        credentials: nil)
      }
      let!(:binding_with_drain10) { ServiceBinding.make(
        syslog_drain_url: 'no_credentials_2',
        app: app_obj4,
        service_instance: instance10,
        credentials: { 'cert' => '', 'key' => '', 'ca' => '' })
      }
      let!(:binding_with_drain11) { ServiceBinding.make(
        syslog_drain_url: 'no_credentials_3',
        app: app_obj,
        service_instance: instance11,
        credentials: { 'foo' => '', 'cert' => '', 'ca' => '' })
      }

      it 'returns a list of syslog drain urls and their credentials' do
        get '/internal/v5/syslog_drain_urls', '{}'
        expect(last_response).to be_successful

        sorted_results = decoded_results.sort { |a, b| a['url'] <=> b['url'] }.each do |binding|
          binding['credentials'].sort! { |a, b| a['cert'] <=> b['cert'] }.each do |credential|
            credential['apps'].sort! { |a, b| a['hostname'] <=> b['hostname'] }
          end
        end

        expect(sorted_results.count).to eq(7)

        expect(sorted_results).to eq(
          [
            { 'url' => 'barfoo',
              'credentials' => [
                { 'cert' => 'cert1',
                  'key' => 'key1',
                  'ca' => 'ca1',
                  'apps' => [{ 'hostname' => 'org-1.space-1.app-3', 'app_id' => app_obj3.guid }] }] },
            { 'url' => 'barfoo2',
              'credentials' => [
                { 'cert' => 'cert1',
                  'key' => 'key1',
                  'ca' => 'ca1',
                  'apps' => [
                    { 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid },
                    { 'hostname' => 'org-1.space-1.app-2', 'app_id' => app_obj2.guid }] },
                { 'cert' => 'cert2',
                  'key' => 'key2',
                  'ca' => 'ca2',
                   'apps' => [
                     { 'hostname' => 'org-1.space-1.app-3', 'app_id' => app_obj3.guid },
                     { 'hostname' => 'org-1.space-1.app-4', 'app_id' => app_obj4.guid }] }] },
            { 'url' => 'fish%2cfinger',
              'credentials' => [
                { 'cert' => '',
                  'key' => '',
                  'ca' => '',
                  'apps' => [{ 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid }] }] },
            { 'url' => 'foobar',
              'credentials' => [
                { 'cert' => '',
                  'key' => '',
                  'ca' => '',
                  'apps' => [
                    { 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid },
                    { 'hostname' => 'org-1.space-1.app-2', 'app_id' => app_obj2.guid }] }] },
            { 'url' => 'no_credentials_1',
              'credentials' => [
                { 'cert' => '',
                  'key' => '',
                  'ca' => '',
                  'apps' => [{ 'hostname' => 'org-1.space-1.app-3', 'app_id' => app_obj3.guid }] }] },
            { 'url' => 'no_credentials_2',
              'credentials' => [
                { 'cert' => '',
                  'key' => '',
                  'ca' => '',
                  'apps' => [{ 'hostname' => 'org-1.space-1.app-4', 'app_id' => app_obj4.guid }] }] },
            { 'url' => 'no_credentials_3',
              'credentials' => [
                { 'cert' => '',
                  'key' => '',
                  'ca' => '',
                  'apps' => [{ 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid }] }] },
          ])
      end

      it 'supports paging' do
        get '/internal/v5/syslog_drain_urls', {
          'batch_size' => 2,
        }
        expect(last_response).to be_successful
        expect(decoded_next_id).to be(2)
        get '/internal/v5/syslog_drain_urls', {
          'batch_size' => 2,
          'next_id' => decoded_next_id
        }
        expect(last_response).to be_successful
        expect(decoded_next_id).to be(4)
        get '/internal/v5/syslog_drain_urls', {
          'batch_size' => 2,
          'next_id' => decoded_next_id
        }
        expect(last_response).to be_successful
        expect(decoded_next_id).to be(6)
        get '/internal/v5/syslog_drain_urls', {
          'batch_size' => 2,
          'next_id' => decoded_next_id
        }
        expect(last_response).to be_successful
        expect(decoded_next_id).to be(8)
        get '/internal/v5/syslog_drain_urls', {
          'batch_size' => 2,
          'next_id' => decoded_next_id
        }
        expect(decoded_next_id).to be(nil)
        expect(decoded_results.length).to be(0)
      end
    end

    def decoded_results
      decoded_response.fetch('results')
    end

    def decoded_next_id
      decoded_response.fetch('next_id')
    end

    def decoded_v5_available
      decoded_response.fetch('v5_available')
    end
  end
end

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

    describe 'GET /internal/v5/syslog_drain_urls' do
      context 'basic functionality' do
        let(:app_obj2) { AppModel.make(name: 'app-2', space: space) }
        let(:app_obj3) { AppModel.make(name: 'app-3', space: space) }
        let(:app_obj4) { AppModel.make(name: 'app-4', space: space) }
        let(:app_obj5) { AppModel.make(name: 'app-5', space: space) }
        let(:instance3) { UserProvidedServiceInstance.make(space: app_obj2.space) }
        let(:instance4) { UserProvidedServiceInstance.make(space: app_obj3.space) }
        let(:instance5) { UserProvidedServiceInstance.make(space: app_obj3.space) }
        let(:instance6) { UserProvidedServiceInstance.make(space: app_obj4.space) }
        let(:instance7) { UserProvidedServiceInstance.make(space: app_obj.space) }
        let(:instance8) { UserProvidedServiceInstance.make(space: app_obj2.space) }
        let(:instance9) { UserProvidedServiceInstance.make(space: app_obj3.space) }
        let(:instance10) { UserProvidedServiceInstance.make(space: app_obj4.space) }
        let(:instance11) { UserProvidedServiceInstance.make(space: app_obj.space) }
        let(:instance12) { UserProvidedServiceInstance.make(space: app_obj.space) }
        let(:instance13) { UserProvidedServiceInstance.make(space: app_obj.space) }
        let(:instance14) { UserProvidedServiceInstance.make(space: app_obj.space) }
        let(:instance15) { UserProvidedServiceInstance.make(space: app_obj.space) }

        before do
          ServiceBinding.make(syslog_drain_url: 'foobar', app: app_obj2, service_instance: instance3)

          ServiceBinding.make(
            syslog_drain_url: 'barfoo',
            app: app_obj3,
            service_instance: instance4,
            credentials: { 'cert' => 'cert1', 'key' => 'key1', 'ca' => 'ca1' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'barfoo2',
            app: app_obj,
            service_instance: instance7,
            credentials: { 'cert' => 'cert1', 'key' => 'key1', 'ca' => 'ca1' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'barfoo2',
            app: app_obj2,
            service_instance: instance8,
            credentials: { 'cert' => 'cert1', 'key' => 'key1', 'ca' => 'ca1' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'barfoo2',
            app: app_obj3,
            service_instance: instance5,
            credentials: { 'cert' => 'cert2', 'key' => 'key2', 'ca' => 'ca2' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'barfoo2',
            app: app_obj4,
            service_instance: instance6,
            credentials: { 'cert' => 'cert2', 'key' => 'key2', 'ca' => 'ca2' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'barfoo2',
            app: app_obj5,
            service_instance: instance6,
            credentials: { 'cert' => 'cert2', 'key' => 'key2', 'ca' => 'ca2' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'no_credentials_1',
            app: app_obj3,
            service_instance: instance9,
            credentials: nil
          )

          ServiceBinding.make(
            syslog_drain_url: 'no_credentials_2',
            app: app_obj4,
            service_instance: instance10,
            credentials: { 'cert' => '', 'key' => '', 'ca' => '' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'no_credentials_3',
            app: app_obj,
            service_instance: instance11,
            credentials: { 'foo' => '', 'cert' => '', 'ca' => '' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'collision_test',
            app: app_obj,
            service_instance: instance12,
            credentials: { 'cert' => '', 'key' => '', 'ca' => '' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'collision_test',
            app: app_obj,
            service_instance: instance13,
            credentials: { 'cert' => 'has-cert', 'key' => '', 'ca' => '' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'collision_test',
            app: app_obj,
            service_instance: instance14,
            credentials: { 'cert' => '', 'key' => 'has-key', 'ca' => '' }
          )

          ServiceBinding.make(
            syslog_drain_url: 'collision_test',
            app: app_obj,
            service_instance: instance15,
            credentials: { 'key' => '', 'cert' => '', 'ca' => 'has-ca' }
          )
        end

        it 'returns a list of syslog drain urls and their credentials' do
          get '/internal/v5/syslog_drain_urls', '{}'
          expect(last_response).to be_successful

          sorted_results = decoded_results.sort { |a, b| a['url'] <=> b['url'] }.each do |binding|
            binding['credentials'].sort! { |a, b| [a['key'], a['cert'], a['ca']] <=> [b['key'], b['cert'], b['ca']] }.each do |credential|
              credential['apps'].sort! { |a, b| a['hostname'] <=> b['hostname'] }
            end
          end

          expect(sorted_results.count).to eq(8)

          expect(sorted_results).to eq(
            [
              { 'url' => 'barfoo',
                'credentials' => [
                  { 'cert' => 'cert1',
                    'key' => 'key1',
                    'ca' => 'ca1',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-3', 'app_id' => app_obj3.guid }] }
                ] },
              { 'url' => 'barfoo2',
                'credentials' => [
                  { 'cert' => 'cert1',
                    'key' => 'key1',
                    'ca' => 'ca1',
                    'apps' => [
                      { 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid },
                      { 'hostname' => 'org-1.space-1.app-2', 'app_id' => app_obj2.guid }
                    ] },
                  { 'cert' => 'cert2',
                    'key' => 'key2',
                    'ca' => 'ca2',
                    'apps' => [
                      { 'hostname' => 'org-1.space-1.app-3', 'app_id' => app_obj3.guid },
                      { 'hostname' => 'org-1.space-1.app-4', 'app_id' => app_obj4.guid },
                      { 'hostname' => 'org-1.space-1.app-5', 'app_id' => app_obj5.guid }
                    ] }
                ] },
              { 'url' => 'collision_test',
                'credentials' => [
                  { 'cert' => '',
                    'key' => '',
                    'ca' => '',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid }] },
                  { 'cert' => '',
                    'key' => '',
                    'ca' => 'has-ca',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid }] },
                  { 'cert' => 'has-cert',
                    'key' => '',
                    'ca' => '',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid }] },
                  { 'cert' => '',
                    'key' => 'has-key',
                    'ca' => '',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid }] }
                ] },
              { 'url' => 'fish%2cfinger',
                'credentials' => [
                  { 'cert' => '',
                    'key' => '',
                    'ca' => '',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid }] }
                ] },
              { 'url' => 'foobar',
                'credentials' => [
                  { 'cert' => '',
                    'key' => '',
                    'ca' => '',
                    'apps' => [
                      { 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid },
                      { 'hostname' => 'org-1.space-1.app-2', 'app_id' => app_obj2.guid }
                    ] }
                ] },
              { 'url' => 'no_credentials_1',
                'credentials' => [
                  { 'cert' => '',
                    'key' => '',
                    'ca' => '',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-3', 'app_id' => app_obj3.guid }] }
                ] },
              { 'url' => 'no_credentials_2',
                'credentials' => [
                  { 'cert' => '',
                    'key' => '',
                    'ca' => '',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-4', 'app_id' => app_obj4.guid }] }
                ] },
              { 'url' => 'no_credentials_3',
                'credentials' => [
                  { 'cert' => '',
                    'key' => '',
                    'ca' => '',
                    'apps' => [{ 'hostname' => 'org-1.space-1.app-1', 'app_id' => app_obj.guid }] }
                ] }
            ]
          )
        end

        describe 'paging' do
          it 'respects the batch_size parameter' do
            [1, 3].each do |size|
              get '/internal/v5/syslog_drain_urls', { 'batch_size' => size }
              expect(last_response).to be_successful
              expect(decoded_results.size).to eq(size)
            end
          end

          it 'returns non-intersecting results when token is supplied' do
            get '/internal/v5/syslog_drain_urls', {
              'batch_size' => 2,
              'next_id' => 0
            }

            saved_results = decoded_results.dup
            expect(saved_results.size).to eq(2)

            get '/internal/v5/syslog_drain_urls', {
              'batch_size' => 2,
              'next_id' => decoded_response['next_id']
            }

            new_results = decoded_results.dup

            urls_saved_results = saved_results.pluck('url')
            urls_new_results = new_results.pluck('url')
            overlap = urls_new_results & urls_saved_results
            expect(overlap).to be_empty
          end

          it 'eventually returns the entire collection, batch after batch' do
            get '/internal/v5/syslog_drain_urls', {
              'batch_size' => 2
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
            expect(decoded_next_id).to be_nil
            expect(decoded_results.length).to be(0)
          end

          context 'when an app has no service_bindings' do
            before do
              AppModel.make(guid: '00000')
            end

            it 'does not affect the paging results' do
              get '/internal/v5/syslog_drain_urls', {
                'batch_size' => 2,
                'next_id' => 0
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
              get '/internal/v5/syslog_drain_urls', {
                'batch_size' => 2,
                'next_id' => 0
              }
              saved_results = decoded_results.dup
              expect(saved_results.size).to eq(2)
            end
          end
        end
      end

      context 'rfc-1034-compliance: whitespace converted to hyphens' do
        let(:org) { Organization.make(name: 'org 2') }
        let(:space) { Space.make(name: 'space 2', organization: org) }
        let(:app_obj) { AppModel.make(name: 'app 2', space: space) }

        it 'truncates trailing hyphens' do
          get '/internal/v5/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(2)
          expect(decoded_results).to include(
            { 'url' => 'fish%2cfinger',
              'credentials' => [
                { 'cert' => '',
                  'key' => '',
                  'ca' => '',
                  'apps' => [{ 'hostname' => 'org-2.space-2.app-2', 'app_id' => app_obj.guid }] }
              ] }
          )
        end
      end

      context 'rfc-1034-compliance: named end with hyphens' do
        let(:org) { Organization.make(name: 'org-3-') }
        let(:space) { Space.make(name: 'space-3--', organization: org) }
        let(:app_obj) { AppModel.make(name: 'app-3---', space: space) }

        it 'truncates trailing hyphens' do
          get '/internal/v5/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(2)
          expect(decoded_results).to include(
            { 'url' => 'fish%2cfinger',
              'credentials' => [
                { 'cert' => '',
                  'key' => '',
                  'ca' => '',
                  'apps' => [{ 'hostname' => 'org-3.space-3.app-3', 'app_id' => app_obj.guid }] }
              ] }
          )
        end
      end

      context 'rfc-1034-compliance: remove disallowed characters' do
        let(:org) { Organization.make(name: '!org@-4#' + [233].pack('U')) }
        let(:space) { Space.make(name: '$space%-^4--&', organization: org) }
        let(:app_obj) { AppModel.make(name: '";*app(-)4_-=-+-[]{}\\|;:,.<>/?`~', space: space) }

        it 'truncates trailing hyphens' do
          get '/internal/v5/syslog_drain_urls', '{}'
          expect(last_response).to be_successful
          expect(decoded_results.count).to eq(2)
          expect(decoded_results).to include(
            { 'url' => 'fish%2cfinger',
              'credentials' => [
                { 'cert' => '',
                  'key' => '',
                  'ca' => '',
                  'apps' => [{ 'hostname' => 'org-4.space-4.app-4', 'app_id' => app_obj.guid }] }
              ] }
          )
        end

        context 'rfc-1034-compliance: truncate overlong name components to first 63' do
          let(:orgName) { 'org-5-' + ('x' * (63 - 6)) }
          let(:orgNamePlus) { orgName + 'y' }
          let(:org) { Organization.make(name: orgNamePlus) }
          let(:spaceName) { 'space-5-' + ('x' * (63 - 8)) }
          let(:spaceNamePlus) { spaceName + 'y' }
          let(:space) { Space.make(name: spaceNamePlus, organization: org) }
          let(:appName) { 'app-5-' + ('x' * (63 - 6)) }
          let(:appNamePlus) { appName + 'y' }
          let(:app_obj) { AppModel.make(name: appNamePlus, space: space) }

          it 'truncates trailing hyphens' do
            get '/internal/v5/syslog_drain_urls', '{}'
            expect(last_response).to be_successful
            expect(decoded_results.count).to eq(2)
            expect(decoded_results).to include(
              { 'url' => 'fish%2cfinger',
                'credentials' => [
                  { 'cert' => '',
                    'key' => '',
                    'ca' => '',
                    'apps' => [{ 'hostname' => "#{orgName}.#{spaceName}.#{appName}", 'app_id' => app_obj.guid }] }
                ] }
            )
          end
        end

        context 'rfc-1034-compliance: keep 63-char names' do
          let(:orgName) { 'org-5-' + ('x' * (63 - 6)) }
          let(:org) { Organization.make(name: orgName) }
          let(:spaceName) { 'space-5-' + ('x' * (63 - 8)) }
          let(:space) { Space.make(name: spaceName, organization: org) }
          let(:appName) { 'app-5-' + ('x' * (63 - 6)) }
          let(:app_obj) { AppModel.make(name: appName, space: space) }

          it 'retains length-compliant names' do
            get '/internal/v5/syslog_drain_urls', '{}'
            expect(last_response).to be_successful
            expect(decoded_results.count).to eq(2)
            expect(decoded_results).to include(
              { 'url' => 'fish%2cfinger',
                'credentials' => [
                  { 'cert' => '',
                    'key' => '',
                    'ca' => '',
                    'apps' => [{ 'hostname' => "#{orgName}.#{spaceName}.#{appName}", 'app_id' => app_obj.guid }] }
                ] }
            )
          end
        end

        context 'when an app has no service binding' do
          let!(:app_no_binding) { AppModel.make }

          it 'does not include that app' do
            get '/internal/v5/syslog_drain_urls', '{}'
            expect(last_response).to be_successful

            expect(
              decoded_results.flat_map do |r|
                r['credentials'].flat_map do |c|
                  c['apps'].map { |a| a['app_id'] }
                end
              end
            ).not_to include(app_no_binding.guid)
          end
        end

        context "when an app's bindings have no syslog_drain_url" do
          let!(:app_no_drain) { ServiceBinding.make.app }

          it 'does not include that app' do
            get '/internal/v5/syslog_drain_urls', '{}'
            expect(last_response).to be_successful
            expect(
              decoded_results.flat_map do |r|
                r['credentials'].flat_map do |c|
                  c['apps'].map { |a| a['app_id'] }
                end
              end
            ).not_to include(app_no_drain.guid)
          end
        end

        context "when an app's binding has blank syslog_drain_urls" do
          let!(:app_empty_drain) { ServiceBinding.make(syslog_drain_url: '').app }

          it 'includes the app without the empty syslog_drain_urls' do
            get '/internal/v5/syslog_drain_urls', '{}'
            expect(last_response).to be_successful
            expect(last_response).to be_successful
            expect(
              decoded_results.flat_map do |r|
                r['credentials'].flat_map do |c|
                  c['apps'].map { |a| a['app_id'] }
                end
              end
            ).not_to include(app_empty_drain.guid)
          end
        end

        context 'when there are many service bindings on a single app' do
          before do
            50.times do |i|
              ServiceBinding.make(
                app: app_obj,
                syslog_drain_url: "syslog://example.com/#{i}",
                service_instance: UserProvidedServiceInstance.make(space: app_obj.space)
              )
            end
          end

          it 'includes all of the syslog_drain_urls for that app' do
            get '/internal/v5/syslog_drain_urls', '{}'
            expect(last_response).to be_successful
            expect(decoded_results.count).to eq(50)
          end
        end
      end

      describe 'endpoint optimizations' do
        before do
          ServiceBinding.dataset.delete
          10.times do
            ServiceBinding.make(syslog_drain_url: 'foodbar.example.com', app: AppModel.make(space: instance1.space), service_instance: instance1)
          end
        end

        it 'only calls .credentials once on the binding' do
          receive_count = 0
          allow_any_instance_of(ServiceBinding).to receive(:credentials) do
            receive_count += 1
            {}
          end

          get '/internal/v5/syslog_drain_urls', { batch_size: 100 }
          expect(last_response).to be_successful
          expect(receive_count).to eq(1)
        end
      end
    end

    def decoded_results
      decoded_response.fetch('results')
    end

    def decoded_next_id
      decoded_response.fetch('next_id')
    end
  end
end

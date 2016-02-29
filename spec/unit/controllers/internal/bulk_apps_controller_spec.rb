require 'spec_helper'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  describe BulkAppsController do
    def make_diego_app(options={})
      AppFactory.make(options).tap do |app|
        app.package_state = 'STAGED'
        app.diego = true
        app.save
      end
    end

    def app_table_entry(index)
      App.order_by(:id).all[index - 1]
    end

    let(:runners) do
      ::CloudController::DependencyLocator.instance.runners
    end

    before do
      allow_any_instance_of(::CloudController::Blobstore::UrlGenerator).
        to receive(:perma_droplet_download_url).
        and_return('http://blobsto.re/droplet')

      @internal_user = 'internal_user'
      @internal_password = 'internal_password'

      5.times { |i| make_diego_app(state: 'STARTED') }
    end

    describe 'GET', '/internal/bulk/apps' do
      context 'without credentials' do
        it 'rejects the request as unauthorized' do
          get '/internal/bulk/apps'
          expect(last_response.status).to eq(401)
        end
      end

      context 'with invalid credentials' do
        before do
          authorize 'bar', 'foo'
        end

        it 'rejects the request as unauthorized' do
          get '/internal/bulk/apps'
          expect(last_response.status).to eq(401)
        end
      end

      context 'with valid credentials' do
        before do
          authorize @internal_user, @internal_password
        end

        it 'requires a token in query string' do
          get '/internal/bulk/apps', {
            'batch_size' => 20,
          }

          expect(last_response.status).to eq(400)
        end

        it 'returns a populated token for the initial request (which has an empty bulk token)' do
          get '/internal/bulk/apps', {
            'batch_size' => 3,
            'token' => '{}',
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response['token']).to eq({ 'id' => app_table_entry(3).id })
        end

        it 'returns apps in the response body' do
          get '/internal/bulk/apps', {
            'batch_size' => 20,
            'token' => { id: app_table_entry(2).id }.to_json,
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response['apps'].size).to eq(3)
        end

        context 'when a format parameter is not specified' do
          before do
            app = make_diego_app(
              state: 'STARTED',
              package_state: 'STAGED',
              package_hash: 'package-hash',
              disk_quota: 1_024,
              environment_json: {
                'env-key-3' => 'env-value-3',
                'env-key-4' => 'env-value-4',
              },
              file_descriptors: 16_384,
              instances: 4,
              memory: 1_024,
              guid: 'app-guid-6',
              command: 'start-command-6',
              stack: Stack.make(name: 'stack-6'),
            )

            route1 = Route.make(
              space: app.space,
              host: 'arsenio',
              domain: SharedDomain.make(name: 'lo-mein.com'),
            )
            app.add_route(route1)
            route2 = Route.make(
              space: app.space,
              host: 'conan',
              domain: SharedDomain.make(name: 'doe-mane.com'),
            )
            app.add_route(route2)

            app.version = 'app-version-6'
            app.save
          end

          it 'uses the desire app message format' do
            get '/internal/bulk/apps', {
              'batch_size' => 100,
              'token' => { id: 0 }.to_json,
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response['apps'].size).to eq(6)

            last_response_app = decoded_response['apps'].last
            last_app = app_table_entry(6)

            expect(last_response_app).to eq(runners.runner_for_app(last_app).desire_app_message)
          end
        end

        context 'when a format=cache parameter is set' do
          it 'uses the cache data format' do
            get '/internal/bulk/apps', {
              'batch_size' => 1,
              'format' => 'fingerprint',
              'token' => { id: 0 }.to_json,
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response['fingerprints'].size).to eq(1)

            app = App.order(:id).first

            message = decoded_response['fingerprints'][0]
            expect(message).to match_object({
              'process_guid' => Diego::ProcessGuid.from_app(app),
              'etag' => app.updated_at.to_f.to_s
            })
          end
        end

        context 'when there are unstaged apps' do
          before do
            app = make_diego_app(state: 'STARTED')
            app.package_state = 'PENDING'
            app.save
          end

          it 'only returns staged apps' do
            get '/internal/bulk/apps', {
              'batch_size' => App.count,
              'token' => '{}',
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response['apps'].size).to eq(App.count - 1)
          end
        end

        context 'when apps are not in the STARTED state' do
          before do
            make_diego_app(state: 'STOPPED')
          end

          it 'does not return apps in the STOPPED state' do
            get '/internal/bulk/apps', {
              'batch_size' => App.count,
              'token' => '{}',
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response['apps'].size).to eq(App.count - 1)
          end
        end

        context 'when there is a mixture of diego and dea apps' do
          before do
            app = AppFactory.make
            expect(app.diego).to be_falsey
          end

          it 'only returns diego apps' do
            get '/internal/bulk/apps', {
              'batch_size' => App.count,
              'token' => '{}',
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response['apps'].size).to eq(App.count - 1)
          end
        end

        context 'when docker is enabled' do
          let(:space) { Space.make }
          let(:docker_app) do
            make_diego_app(docker_image: 'some-image', state: 'STARTED')
          end

          before do
            FeatureFlag.create(name: 'diego_docker', enabled: true)
            TestConfig.override(diego: { staging: 'optional', running: 'optional' })
          end

          it 'does return docker apps' do
            get '/internal/bulk/apps', {
              'batch_size' => App.count,
              'token' => '{}',
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response['apps'].size).to eq(App.count)
          end
        end

        describe 'pagination' do
          it 'respects the batch_size parameter' do
            [3, 5].each { |size|
              get '/internal/bulk/apps', {
                'batch_size' => size,
                'token' => { id: 0 }.to_json,
              }

              expect(last_response.status).to eq(200)
              expect(decoded_response['apps'].size).to eq(size)
            }
          end

          it 'returns non-intersecting apps when token is supplied' do
            get '/internal/bulk/apps', {
              'batch_size' => 2,
              'token' => { id: 0 }.to_json,
            }

            expect(last_response.status).to eq(200)

            saved_apps = decoded_response['apps'].dup
            expect(saved_apps.size).to eq(2)

            get '/internal/bulk/apps', {
              'batch_size' => 2,
              'token' => MultiJson.dump(decoded_response['token']),
            }

            expect(last_response.status).to eq(200)

            new_apps = decoded_response['apps'].dup
            expect(new_apps.size).to eq(2)
            saved_apps.each do |saved_result|
              expect(new_apps).not_to include(saved_result)
            end
          end

          it 'should eventually return entire collection, batch after batch' do
            apps = []
            total_size = App.count

            token = '{}'
            while apps.size < total_size
              get '/internal/bulk/apps', {
                'batch_size' => 2,
                'token' => MultiJson.dump(token),
              }

              expect(last_response.status).to eq(200)
              token = decoded_response['token']
              apps += decoded_response['apps']
            end

            expect(apps.size).to eq(total_size)
            get '/internal/bulk/apps', {
              'batch_size' => 2,
              'token' => MultiJson.dump(token),
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response['apps'].size).to eq(0)
          end
        end
      end
    end

    describe 'POST /internal/bulk/apps' do
      context 'without credentials' do
        it 'rejects the request as unauthorized' do
          post '/internal/bulk/apps', {}

          expect(last_response.status).to eq(401)
        end
      end

      context 'with invalid credentials' do
        before do
          authorize 'bar', 'foo'
        end

        it 'rejects the request as unauthorized' do
          post '/internal/bulk/apps'

          expect(last_response.status).to eq(401)
        end
      end

      context 'with valid credentials' do
        before do
          authorize @internal_user, @internal_password
        end

        context 'without a body' do
          it 'is an invalid request' do
            post '/internal/bulk/apps'

            expect(last_response.status).to eq(400)
          end
        end

        context 'with a body' do
          context 'with invalid json' do
            it 'is an invalid request' do
              post '/internal/bulk/apps', 'foo'

              expect(last_response.status).to eq(400)
            end
          end

          context 'with an empty list' do
            it 'returns an empty list' do
              post '/internal/bulk/apps', [].to_json

              expect(last_response.status).to eq(200)
              expect(decoded_response).to eq([])
            end
          end

          context 'with a list of process guids' do
            it 'returns a list of desire app messages that match the process guids' do
              diego_apps = runners.diego_apps(100, 0)

              guids = diego_apps.map { |app| Diego::ProcessGuid.from_app(app) }
              post '/internal/bulk/apps', guids.to_json

              expect(last_response.status).to eq(200)
              expect(decoded_response.length).to eq(5)

              diego_apps.each do |app|
                expect(decoded_response).to include(runners.runner_for_app(app).desire_app_message)
              end
            end

            context 'when there is a mixture of diego and dea apps' do
              before do
                5.times { AppFactory.make }
              end

              it 'only returns the diego apps' do
                diego_apps = runners.diego_apps(100, 0)

                guids = App.all.map { |app| Diego::ProcessGuid.from_app(app) }
                post '/internal/bulk/apps', guids.to_json

                expect(last_response.status).to eq(200)
                expect(decoded_response.length).to eq(diego_apps.length)
              end
            end
          end

          # validate max batch size; reject requests that are too large
        end
      end
    end
  end
end

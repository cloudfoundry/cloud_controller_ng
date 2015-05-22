require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::LegacyServiceGateway, :services do
    describe 'Gateway facing apis' do
      def build_offering(attrs={})
        defaults = {
          label: 'foobar-1.0',
          url: 'https://www.google.com',
          supported_versions: ['1.0', '2.0'],
          version_aliases: { 'current' => '2.0' },
          description: 'the foobar svc',
        }
        VCAP::Services::Api::ServiceOfferingRequest.new(defaults.merge(attrs))
      end

      describe 'POST services/v1/offerings' do
        let(:path) { 'services/v1/offerings' }

        let(:auth_header) do
          ServiceAuthToken.create(
            label: 'foobar',
            provider: 'core',
            token: 'foobar',
          )

          { 'HTTP_X_VCAP_SERVICE_TOKEN' => 'foobar' }
        end

        let(:foo_bar_dash_offering) do
          VCAP::Services::Api::ServiceOfferingRequest.new(
            label: 'foo-bar-1.0',
            url: 'https://www.google.com',
            supported_versions: ['1.0', '2.0'],
            version_aliases: { 'current' => '2.0' },
            description: 'the foobar svc')
        end

        it 'should reject requests without auth tokens' do
          post path, build_offering.encode, {}
          expect(last_response.status).to eq(403)
        end

        it 'should should reject posts with malformed bodies' do
          post path, MultiJson.dump(bla: 'foobar'), auth_header
          expect(last_response.status).to eq(400)
        end

        it 'should reject requests with missing parameters' do
          msg = { label: 'foobar-2.2',
                  description: 'the foobar svc' }
          post path, MultiJson.dump(msg), auth_header
          expect(last_response.status).to eq(400)
        end

        it 'should reject requests with extra dash in label' do
          post path, foo_bar_dash_offering.encode, auth_header
          expect(last_response.status).to eq(400)
        end

        it 'should create service offerings for label/provider services' do
          post path, build_offering.encode, auth_header
          expect(last_response.status).to eq(200)
          svc = Service.find(label: 'foobar', provider: 'core')
          expect(svc).not_to be_nil
          expect(svc.version).to eq('2.0')
        end

        it "should create services with 'extra' data" do
          extra_data = "{\"I\": \"am json #{'more' * 100}\"}"
          o = build_offering
          o.extra = extra_data
          post path, o.encode, auth_header

          expect(last_response.status).to eq(200)
          service = Service[label: 'foobar', provider: 'core']
          expect(service.extra).to eq(extra_data)
        end

        it 'should set bindable to true' do
          post path, build_offering.encode, auth_header

          expect(last_response.status).to eq(200)
          service = Service[label: 'foobar', provider: 'core']
          expect(service.bindable).to eq(true)
        end

        shared_examples_for 'offering containing service plans' do
          it 'should create service plans' do
            post path, both_plans.encode, auth_header

            service = Service[label: 'foobar', provider: 'core']
            expect(service.service_plans.map(&:name)).to include('free', 'nonfree')
          end

          it 'should update service plans' do
            post path, just_free_plan.encode, auth_header
            post path, both_plans.encode, auth_header

            service = Service[label: 'foobar', provider: 'core']
            expect(service.service_plans.map(&:name)).to include('free', 'nonfree')
          end

          it 'should remove plans not posted' do
            post path, both_plans.encode, auth_header
            post path, just_free_plan.encode, auth_header

            service = Service[label: 'foobar', provider: 'core']
            expect(service.service_plans.map(&:name)).to eq(['free'])
          end
        end

        context "using the deprecated 'plans' key" do
          it_behaves_like 'offering containing service plans' do
            let(:just_free_plan) { build_offering(plans: %w(free)) }
            let(:both_plans)     { build_offering(plans: %w(free nonfree)) }
          end
        end

        context "using the 'plan_details' key" do
          let(:just_free_plan) { build_offering(plan_details: [{ 'name' => 'free', 'free' => true }]) }
          let(:both_plans) {
            build_offering(
              plan_details: [
                { 'name' => 'free',    'free' => true },
                { 'name' => 'nonfree', 'free' => false },
              ]
            )
          }

          it_behaves_like 'offering containing service plans'

          it 'puts the details into the db' do
            offer = build_offering(
              plan_details: [
                {
                  'name'        => 'freeplan',
                  'free'        => true,
                  'description' => 'free plan',
                  'extra'       => 'extra info',
                }
              ]
            )
            post path, offer.encode, auth_header
            expect(last_response.status).to eq(200)

            service = Service[label: 'foobar', provider: 'core']
            expect(service.service_plans).to have(1).entries
            expect(service.service_plans.first.description).to eq('free plan')
            expect(service.service_plans.first.name).to eq('freeplan')
            expect(service.service_plans.first.free).to eq(true)
            expect(service.service_plans.first.extra).to eq('extra info')
          end

          it 'does not add plans with identical names but different freeness under the same service' do
            post path, just_free_plan.encode, auth_header
            expect(last_response.status).to eq(200)

            offer2 = build_offering(plan_details: [{ 'name' => 'free', 'free' => false, 'description' => 'tetris' }])
            post path, offer2.encode, auth_header
            expect(last_response.status).to eq(200)

            service = Service[label: 'foobar', provider: 'core']
            expect(service).to have(1).service_plans
            expect(service.service_plans.first.description).to eq('tetris')
            expect(service.service_plans.first.free).to eq(false)
          end

          it 'prevents the request from setting the plan guid' do
            offer = build_offering(
              plan_details: [{ 'name' => 'plan name', 'free' => true, 'guid' => 'myguid' }]
            )
            post path, offer.encode, auth_header
            expect(last_response.status).to eq(200)

            service = Service[label: 'foobar', provider: 'core']
            expect(service).to have(1).service_plans
            expect(service.service_plans.first.guid).not_to eq('myguid')
          end
        end

        context "using both the 'plan_details' key and the deprecated 'plans' key" do
          it_behaves_like 'offering containing service plans' do
            let(:just_free_plan) {
              build_offering(
                plan_details: [{ 'name' => 'free', 'free' => true }],
                plans: %w(free),
              )
            }

            let(:both_plans) {
              build_offering(
                plan_details: [
                  { 'name' => 'free',    'free' => true },
                  { 'name' => 'nonfree', 'free' => false },
                ],
                plans: %w(free nonfree),
              )
            }
          end
        end

        it 'should update service offerings for label/provider services' do
          post path, build_offering.encode, auth_header
          offer = build_offering
          offer.url = 'http://newurl.com'
          post path, offer.encode, auth_header
          expect(last_response.status).to eq(200)
          svc = Service.find(label: 'foobar', provider: 'core')
          expect(svc).not_to be_nil
          expect(svc.url).to eq('http://newurl.com')
        end
      end

      describe 'GET services/v1/offerings/:label_and_version(/:provider)' do
        before :each do
          @svc1 = Service.make(:v1,
            label: 'foobar',
            url: 'http://www.google.com',
            provider: 'core',
          )
          ServicePlan.make(:v1,
            name: 'free',
            service: @svc1,
          )
          ServicePlan.make(:v1,
            name: 'nonfree',
            service: @svc1,
          )
          @svc2 = Service.make(:v1,
            label: 'foobar',
            url: 'http://www.google.com',
            provider: 'test',
          )
          ServicePlan.make(:v1,
            name: 'free',
            service: @svc2,
          )
          ServicePlan.make(:v1,
            name: 'nonfree',
            service: @svc2,
          )
        end

        let(:auth_header) { { 'HTTP_X_VCAP_SERVICE_TOKEN' => @svc1.service_auth_token.token } }

        it 'should return not found for unknown label services' do
          get 'services/v1/offerings/xxx', {}, auth_header
          expect(last_response.status).to eq(403)
        end

        it 'should return not found for unknown provider services' do
          get 'services/v1/offerings/foobar-version/xxx', {}, auth_header
          expect(last_response.status).to eq(403)
        end

        it 'should return not authorized on token mismatch' do
          get 'services/v1/offerings/foobar-version', {}, {
            'HTTP_X_VCAP_SERVICE_TOKEN' => 'xxx',
          }
          expect(last_response.status).to eq(403)
        end

        it 'should return the specific service offering which has null provider' do
          get 'services/v1/offerings/foobar-version', {}, auth_header
          expect(last_response.status).to eq(200)

          resp = MultiJson.load(last_response.body)
          expect(resp['label']).to eq('foobar')
          expect(resp['url']).to eq('http://www.google.com')
          expect(resp['plans'].sort).to eq(%w(free nonfree))
          expect(resp['provider']).to eq('core')
        end

        it 'should return the specific service offering which has specific provider' do
          get 'services/v1/offerings/foobar-version/test', {}, { 'HTTP_X_VCAP_SERVICE_TOKEN' => @svc2.service_auth_token.token }
          expect(last_response.status).to eq(200)

          resp = MultiJson.load(last_response.body)
          expect(resp['label']).to eq('foobar')
          expect(resp['url']).to eq('http://www.google.com')
          expect(resp['plans'].sort).to eq(%w(free nonfree))
          expect(resp['provider']).to eq('test')
        end
      end

      describe 'GET services/v1/offerings/:label_and_version(/:provider)/handles' do
        let!(:svc1) { Service.make(:v1, label: 'foobar', version: '1.0', provider: 'core') }
        let!(:svc2) { Service.make(:v1, label: 'foobar', version: '1.0', provider: 'test') }

        before do
          plan1 = ServicePlan.make(:v1, service: svc1)
          plan2 = ServicePlan.make(:v1, service: svc2)

          cfg1 = ManagedServiceInstance.make(:v1,
            name: 'bar1',
            service_plan: plan1
          )
          cfg1.gateway_name = 'foo1'
          cfg1.gateway_data = { config: 'foo1' }
          cfg1.save

          cfg2 = ManagedServiceInstance.make(:v1,
            name: 'bar2',
            service_plan: plan2
          )
          cfg2.gateway_name = 'foo2'
          cfg2.gateway_data = { config: 'foo2' }
          cfg2.save

          ServiceBinding.make(
            gateway_name: 'bind1',
            service_instance: cfg1,
            gateway_data: { config: 'bind1' },
            credentials: {}
          )
          ServiceBinding.make(
            gateway_name: 'bind2',
            service_instance: cfg2,
            gateway_data: { config: 'bind2' },
            credentials: {}
          )
        end

        it 'should return not found for unknown services' do
          get 'services/v1/offerings/xxx-version/handles'
          expect(last_response.status).to eq(404)
        end

        it 'should return not found for unknown services with a provider' do
          get 'services/v1/offerings/xxx-version/fooprovider/handles'
          expect(last_response.status).to eq(404)
        end

        it 'rejects requests with mismatching tokens' do
          get '/services/v1/offerings/foobar-version/handles', {}, {
            'HTTP_X_VCAP_SERVICE_TOKEN' => 'xxx',
          }
          expect(last_response.status).to eq(403)
        end

        it 'should return provisioned and bound handles' do
          get '/services/v1/offerings/foobar-version/handles', {}, { 'HTTP_X_VCAP_SERVICE_TOKEN' => svc1.service_auth_token.token }
          expect(last_response.status).to eq(200)

          handles = JSON.parse(last_response.body)['handles']
          expect(handles.size).to eq(2)
          expect(handles[0]['service_id']).to eq('foo1')
          expect(handles[0]['configuration']).to eq({ 'config' => 'foo1' })
          expect(handles[1]['service_id']).to eq('bind1')
          expect(handles[1]['configuration']).to eq({ 'config' => 'bind1' })

          get '/services/v1/offerings/foobar-version/test/handles', {}, { 'HTTP_X_VCAP_SERVICE_TOKEN' => svc2.service_auth_token.token }
          expect(last_response.status).to eq(200)

          handles = JSON.parse(last_response.body)['handles']
          expect(handles.size).to eq(2)
          expect(handles[0]['service_id']).to eq('foo2')
          expect(handles[0]['configuration']).to eq({ 'config' => 'foo2' })
          expect(handles[1]['service_id']).to eq('bind2')
          expect(handles[1]['configuration']).to eq({ 'config' => 'bind2' })
        end
      end

      describe 'POST services/v1/offerings/:label_and_version(/:provider)/handles/:id' do
        let!(:svc) { Service.make(:v1, label: 'foobar', provider: 'core') }

        before { @auth_header = { 'HTTP_X_VCAP_SERVICE_TOKEN' => svc.service_auth_token.token } }

        describe 'with default provider' do
          before :each do
            plan = ServicePlan.make(:v1, service: svc)
            cfg = ManagedServiceInstance.make(:v1, name: 'bar1', service_plan: plan)
            cfg.gateway_name = 'foo1'
            cfg.save

            ServiceBinding.make(
              service_instance: cfg,
              gateway_name: 'bind1',
              gateway_data: {},
              credentials: {}
            )
          end

          it 'should return not found for unknown handles' do
            post 'services/v1/offerings/foobar-version/handles/xxx',
              VCAP::Services::Api::HandleUpdateRequest.new(
                service_id: 'xxx',
                configuration: [],
                credentials: []
            ).encode, @auth_header
            expect(last_response.status).to eq(404)
          end

          it 'should update provisioned handles' do
            post 'services/v1/offerings/foobar-version/handles/foo1',
              VCAP::Services::Api::HandleUpdateRequest.new(
                service_id: 'foo1',
                configuration: [],
                credentials: { foo: 'bar' }
            ).encode, @auth_header
            expect(last_response.status).to eq(200)
          end

          it 'should update bound handles' do
            post '/services/v1/offerings/foobar-version/handles/bind1',
              VCAP::Services::Api::HandleUpdateRequest.new(
                service_id: 'bind1',
                configuration: [],
                credentials: []
            ).encode, @auth_header
            expect(last_response.status).to eq(200)
          end
        end

        describe 'with specific provider' do
          let!(:svc) { Service.make(:v1, label: 'foobar', provider: 'test') }

          before :each do
            plan = ServicePlan.make(:v1,
              service: svc
            )

            cfg = ManagedServiceInstance.make(:v1,
              name: 'bar2',
              service_plan: plan,
            )
            cfg.gateway_name = 'foo2'
            cfg.save

            ServiceBinding.make(
              service_instance: cfg,
              gateway_name: 'bind2',
              gateway_data: {},
              credentials: {},
            )
          end

          it 'should update provisioned handles' do
            post '/services/v1/offerings/foobar-version/test/handles/foo2',
              VCAP::Services::Api::HandleUpdateRequest.new(
                service_id: 'foo2',
                configuration: [],
                credentials: { foo: 'bar' }
            ).encode, @auth_header
            expect(last_response.status).to eq(200)
          end

          it 'should update bound handles' do
            post '/services/v1/offerings/foobar-version/test/handles/bind2',
              VCAP::Services::Api::HandleUpdateRequest.new(
                service_id: 'bind2',
                configuration: [],
                credentials: []
            ).encode, @auth_header
            expect(last_response.status).to eq(200)
          end
        end
      end

      describe 'DELETE /services/v1/offerings/:label_and_version/(:provider)' do
        let!(:service_plan_core) { ServicePlan.make(:v1, service: Service.make(:v1, label: 'foobar', provider: 'core')) }
        let!(:service_plan_test) { ServicePlan.make(:v1, service: Service.make(:v1, label: 'foobar', provider: 'test')) }
        let(:auth_header) { { 'HTTP_X_VCAP_SERVICE_TOKEN' => service_plan_core.service.service_auth_token.token } }

        it 'should return not found for unknown label services' do
          delete '/services/v1/offerings/xxx', {}, auth_header
          expect(last_response.status).to eq(403)
        end

        it 'should return not found for unknown provider services' do
          delete '/services/v1/offerings/foobar-version/xxx', {}, auth_header
          expect(last_response.status).to eq(403)
        end

        it 'should return not authorized on token mismatch' do
          delete '/services/v1/offerings/foobar-version/xxx', {}, {
            'HTTP_X_VCAP_SERVICE_TOKEN' => 'barfoo',
          }
          expect(last_response.status).to eq(403)
        end

        it 'should delete existing offerings which has null provider' do
          delete '/services/v1/offerings/foobar-version', {}, auth_header
          expect(last_response.status).to eq(200)

          svc = Service[label: 'foobar', provider: 'core']
          expect(svc).to be_nil
        end

        it 'should delete existing offerings which has specific provider' do
          delete '/services/v1/offerings/foobar-version/test', {}, { 'HTTP_X_VCAP_SERVICE_TOKEN' => service_plan_test.service.service_auth_token.token }
          expect(last_response.status).to eq(200)

          svc = Service[label: 'foobar', provider: 'test']
          expect(svc).to be_nil
        end
      end
    end
  end
end

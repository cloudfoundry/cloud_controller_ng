require 'spec_helper'

module VCAP::CloudController
  # port of the legacy cc info spec, minus legacy token support. i.e. this is jwt
  # tokens only.
  RSpec.describe VCAP::CloudController::LegacyInfo do
    it 'is deprecated' do
      get '/info'
      expect(last_response).to be_a_deprecated_response
    end

    it "returns a 'user' entry when authenticated" do
      set_current_user_as_admin
      get '/info'
      hash = MultiJson.load(last_response.body)
      expect(hash).to have_key('user')
    end

    it "excludes the 'user' entry when not authenticated" do
      get '/info'
      hash = MultiJson.load(last_response.body)
      expect(hash).not_to have_key('user')
    end

    it 'includes data from the config' do
      get '/info'
      hash = MultiJson.load(last_response.body)
      expect(hash['name']).to eq(TestConfig.config_instance.get(:info, :name))
      expect(hash['build']).to eq(TestConfig.config_instance.get(:info, :build))
      expect(hash['support']).to eq(TestConfig.config_instance.get(:info, :support_address))
      expect(hash['version']).to eq(TestConfig.config_instance.get(:info, :version))
      expect(hash['description']).to eq(TestConfig.config_instance.get(:info, :description))
      expect(hash['authorization_endpoint']).to eq(TestConfig.config_instance.get(:uaa, :url))
      expect(hash['token_endpoint']).to eq(TestConfig.config_instance.get(:uaa, :url))
      expect(hash['allow_debug']).to eq(true)
    end

    it 'includes login url when configured' do
      TestConfig.override(login: { url: 'login_url' })
      get '/info'
      hash = MultiJson.load(last_response.body)
      expect(hash['authorization_endpoint']).to eq('login_url')
    end

    describe 'account capacity' do
      before { set_current_user(current_user) }

      describe 'for an admin' do
        let(:current_user) { make_user_with_default_space(admin: true) }

        it 'should return admin limits for an admin' do
          get '/info'
          expect(last_response.status).to eq(200)
          hash = MultiJson.load(last_response.body)
          expect(hash).to have_key('limits')
          expect(hash['limits']).to eq({
            'memory' => AccountCapacity::ADMIN_MEM,
            'app_uris' => AccountCapacity::ADMIN_URIS,
            'services' => AccountCapacity::ADMIN_SERVICES,
            'apps' => AccountCapacity::ADMIN_APPS
          })
        end
      end

      describe 'for a user with no default space' do
        let(:current_user) { make_user }

        it 'should not return service usage' do
          get '/info'
          expect(last_response.status).to eq(200)
          hash = MultiJson.load(last_response.body)
          expect(hash).not_to have_key('usage')
        end
      end

      describe 'for a user with default space' do
        let(:current_user) { make_user_with_default_space }

        it 'should return default limits for a user' do
          get '/info'
          expect(last_response.status).to eq(200)
          hash = MultiJson.load(last_response.body)
          expect(hash).to have_key('limits')
          expect(hash['limits']).to eq({
            'memory' => AccountCapacity::DEFAULT_MEM,
            'app_uris' => AccountCapacity::DEFAULT_URIS,
            'services' => AccountCapacity::DEFAULT_SERVICES,
            'apps' => AccountCapacity::DEFAULT_APPS
          })
        end

        context 'with no apps and services' do
          it 'should return 0 apps and service usage' do
            get '/info'
            expect(last_response.status).to eq(200)
            hash = MultiJson.load(last_response.body)
            expect(hash).to have_key('usage')

            expect(hash['usage']).to eq({
              'memory' => 0,
              'apps' => 0,
              'services' => 0
            })
          end
        end

        context 'with 2 started apps with 2 instances, 5 stopped apps, and 3 service' do
          before do
            2.times do
              ProcessModelFactory.make(
                space: current_user.default_space,
                state: 'STARTED',
                instances: 2,
                memory: 128,
              )
            end

            5.times do
              ProcessModelFactory.make(
                space: current_user.default_space,
                state: 'STOPPED',
                instances: 2,
                memory: 128
              )
            end

            3.times do
              ManagedServiceInstance.make(space: current_user.default_space)
            end
          end

          it 'should return 2 apps and 3 services' do
            get '/info'
            expect(last_response.status).to eq(200)
            hash = MultiJson.load(last_response.body)
            expect(hash).to have_key('usage')

            expect(hash['usage']).to eq({
              'memory' => 128 * 4,
              'apps' => 2,
              'services' => 3
            })
          end
        end
      end
    end
  end
end

require 'spec_helper'

module VCAP::CloudController
  # port of the legacy cc info spec, minus legacy token support. i.e. this is jwt
  # tokens only.
  describe VCAP::CloudController::LegacyInfo do
    it 'is deprecated' do
      get '/info', {}, {}
      expect(last_response).to be_a_deprecated_response
    end

    it "returns a 'user' entry when authenticated" do
      get '/info', {}, admin_headers
      hash = MultiJson.load(last_response.body)
      expect(hash).to have_key('user')
    end

    it "excludes the 'user' entry when not authenticated" do
      get '/info', {}, {}
      hash = MultiJson.load(last_response.body)
      expect(hash).not_to have_key('user')
    end

    it 'includes data from the config' do
      get '/info', {}, {}
      hash = MultiJson.load(last_response.body)
      expect(hash['name']).to eq(TestConfig.config[:info][:name])
      expect(hash['build']).to eq(TestConfig.config[:info][:build])
      expect(hash['support']).to eq(TestConfig.config[:info][:support_address])
      expect(hash['version']).to eq(TestConfig.config[:info][:version])
      expect(hash['description']).to eq(TestConfig.config[:info][:description])
      expect(hash['authorization_endpoint']).to eq(TestConfig.config[:uaa][:url])
      expect(hash['token_endpoint']).to eq(TestConfig.config[:uaa][:url])
      expect(hash['allow_debug']).to eq(TestConfig.config.fetch(:allow_debug, true))
    end

    it 'includes login url when configured' do
      TestConfig.override(login: { url: 'login_url' })
      get '/info', {}, {}
      hash = MultiJson.load(last_response.body)
      expect(hash['authorization_endpoint']).to eq('login_url')
    end

    describe 'account capacity' do
      let(:headers) { headers_for(current_user) }

      describe 'for an admin' do
        let(:current_user) { make_user_with_default_space(admin: true) }

        it 'should return admin limits for an admin' do
          get '/info', {}, headers
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
          get '/info', {}, headers
          expect(last_response.status).to eq(200)
          hash = MultiJson.load(last_response.body)
          expect(hash).not_to have_key('usage')
        end
      end

      describe 'for a user with default space' do
        let(:current_user) { make_user_with_default_space }

        it 'should return default limits for a user' do
          get '/info', {}, headers
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
            get '/info', {}, headers
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
              AppFactory.make(
                space: current_user.default_space,
                state: 'STARTED',
                instances: 2,
                memory: 128,
                package_hash: 'abc',
                package_state: 'STAGED'
              )
            end

            5.times do
              AppFactory.make(
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
            get '/info', {}, headers
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

    describe 'service info' do
      before do
        @mysql_svc = Service.make(:v1,
          label: 'mysql',
          provider: 'core',
        )

        ServicePlan.make(:v1, service: @mysql_svc, name: '100')

        @pg_svc = Service.make(:v1,
          label: 'postgresql',
          provider: 'core',
        )

        ServicePlan.make(:v1, service: @pg_svc, name: '100')

        @redis_svc = Service.make(:v1,
          label: 'redis',
          provider: 'core',
        )

        ServicePlan.make(:v1, service: @redis_svc, name: '100')

        @mongo_svc = Service.make(:v1,
          label: 'mongodb',
          provider: 'core',
        )

        ServicePlan.make(:v1, service: @mongo_svc, name: '100')

        @random_svc = Service.make(:v1,
          label: 'random',
          provider: 'core',
        )

        ServicePlan.make(:v1, service: @random_svc, name: '100')

        @random_other_svc = Service.make(:v1,
          label: 'random_other',
          provider: 'core',
        )

        ServicePlan.make(:v1,
          service: @random_other_svc,
          name: 'other'
        )

        Service.make(:v1)

        get '/info/services', {}, headers_for(User.make)
      end

      it 'should return synthesized types as the top level key' do
        expect(last_response.status).to eq(200)
        hash = MultiJson.load(last_response.body)
        expect(hash).to have_key('database')
        expect(hash).to have_key('key-value')
        expect(hash).to have_key('generic')

        expect(hash['database'].length).to eq(2)
        expect(hash['key-value'].length).to eq(2)
        expect(hash['generic'].length).to eq(1)
      end

      it 'should return mysql as a database' do
        hash = MultiJson.load(last_response.body)
        expect(hash['database']).to have_key('mysql')
        expect(hash['database']['mysql']).to eq({
          @mysql_svc.version => {
            'id' => @mysql_svc.guid,
            'vendor' => 'mysql',
            'version' => @mysql_svc.version,
            'type' => 'database',
            'description' => @mysql_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should return pg as a database' do
        hash = MultiJson.load(last_response.body)
        expect(hash['database']).to have_key('postgresql')
        expect(hash['database']['postgresql']).to eq({
          @pg_svc.version => {
            'id' => @pg_svc.guid,
            'vendor' => 'postgresql',
            'version' => @pg_svc.version,
            'type' => 'database',
            'description' => @pg_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should return redis under key-value' do
        hash = MultiJson.load(last_response.body)
        expect(hash['key-value']).to have_key('redis')
        expect(hash['key-value']['redis']).to eq({
          @redis_svc.version => {
            'id' => @redis_svc.guid,
            'vendor' => 'redis',
            'version' => @redis_svc.version,
            'type' => 'key-value',
            'description' => @redis_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should (incorrectly) return mongo under key-value' do
        hash = MultiJson.load(last_response.body)
        expect(hash['key-value']).to have_key('mongodb')
        expect(hash['key-value']['mongodb']).to eq({
          @mongo_svc.version => {
            'id' => @mongo_svc.guid,
            'vendor' => 'mongodb',
            'version' => @mongo_svc.version,
            'type' => 'key-value',
            'description' => @mongo_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should return random under generic' do
        hash = MultiJson.load(last_response.body)
        expect(hash['generic']).to have_key('random')
        expect(hash['generic']['random']).to eq({
          @random_svc.version => {
            'id' => @random_svc.guid,
            'vendor' => 'random',
            'version' => @random_svc.version,
            'type' => 'generic',
            'description' => @random_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should filter service with non-100 plan' do
        hash = MultiJson.load(last_response.body)
        expect(hash['database']).not_to have_key('random_other')
        expect(hash['key-value']).not_to have_key('random_other')
        expect(hash['generic']).not_to have_key('random_other')
      end
    end

    describe 'GET /info/services unauthenticated' do
      before(:each) do
        # poor man's reset_db
        Service.filter(provider: 'core').each do |svc|
          svc.service_plans_dataset.filter(name: '100').destroy
          svc.destroy
        end
        @mysql_svc = Service.make(:v1,
          label: "mysql_#{Sham.name}",
          provider: 'core',
        )
        ServicePlan.make(:v1,
          service: @mysql_svc,
          name: '100',
        )
        @pg_svc = Service.make(:v1,
          label: "postgresql_#{Sham.name}",
          provider: 'core',
        )
        ServicePlan.make(:v1,
          service: @pg_svc,
          name: '100',
        )
        @redis_svc = Service.make(:v1,
          label: "redis_#{Sham.name}",
          provider: 'core',
        )
        ServicePlan.make(:v1,
          service: @redis_svc,
          name: '100',
        )
        @mongo_svc = Service.make(:v1,
          label: "mongodb_#{Sham.name}",
          provider: 'core',
        )
        ServicePlan.make(:v1,
          service: @mongo_svc,
          name: '100',
        )
        @random_svc = Service.make(:v1,
          label: "random_#{Sham.name}",
          provider: 'core',
        )
        ServicePlan.make(:v1,
          service: @random_svc,
          name: '100',
        )
        non_core = Service.make(:v1)
        ServicePlan.make(:v1,
          service: non_core,
          name: '100',
        )

        get '/info/services', {}
      end

      it 'should return synthesized types as the top level key' do
        expect(last_response.status).to eq(200)
        hash = MultiJson.load(last_response.body)
        expect(hash).to have_key('database')
        expect(hash).to have_key('key-value')
        expect(hash).to have_key('generic')

        expect(hash['database'].length).to eq(2)
        expect(hash['key-value'].length).to eq(2)
        expect(hash['generic'].length).to eq(1)
      end

      it 'should return mysql as a database' do
        hash = MultiJson.load(last_response.body)
        expect(hash['database']).to have_key(@mysql_svc.label)
        expect(hash['database'][@mysql_svc.label]).to eq({
          @mysql_svc.version => {
            'id' => @mysql_svc.guid,
            'vendor' => @mysql_svc.label,
            'version' => @mysql_svc.version,
            'type' => 'database',
            'description' => @mysql_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should return pg as a database' do
        hash = MultiJson.load(last_response.body)
        expect(hash['database']).to have_key(@pg_svc.label)
        expect(hash['database'][@pg_svc.label]).to eq({
          @pg_svc.version => {
            'id' => @pg_svc.guid,
            'vendor' => @pg_svc.label,
            'version' => @pg_svc.version,
            'type' => 'database',
            'description' => @pg_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should return redis under key-value' do
        hash = MultiJson.load(last_response.body)
        expect(hash['key-value']).to have_key(@redis_svc.label)
        expect(hash['key-value'][@redis_svc.label]).to eq({
          @redis_svc.version => {
            'id' => @redis_svc.guid,
            'vendor' => @redis_svc.label,
            'version' => @redis_svc.version,
            'type' => 'key-value',
            'description' => @redis_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should (incorrectly) return mongo under key-value' do
        hash = MultiJson.load(last_response.body)
        expect(hash['key-value']).to have_key(@mongo_svc.label)
        expect(hash['key-value'][@mongo_svc.label]).to eq({
          @mongo_svc.version => {
            'id' => @mongo_svc.guid,
            'vendor' => @mongo_svc.label,
            'version' => @mongo_svc.version,
            'type' => 'key-value',
            'description' => @mongo_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end

      it 'should return random under generic' do
        hash = MultiJson.load(last_response.body)
        expect(hash['generic']).to have_key(@random_svc.label)
        expect(hash['generic'][@random_svc.label]).to eq({
          @random_svc.version => {
            'id' => @random_svc.guid,
            'vendor' => @random_svc.label,
            'version' => @random_svc.version,
            'type' => 'generic',
            'description' => @random_svc.description,
            'tiers' => {
              'free' => {
                'options' => {},
                'order' => 1
              }
            }
          }
        })
      end
    end
  end
end

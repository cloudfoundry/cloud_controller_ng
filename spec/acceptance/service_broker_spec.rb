require 'spec_helper'

RSpec.describe 'Service Broker' do
  include VCAP::CloudController::BrokerApiHelper

  let(:small_plan) do
    {
      id: 'plan-1',
      name: 'small',
      description: 'A small shared database with 100mb storage quota and 10 connections',
      schemas: {
        service_instance: {
          create: {
            parameters: { '$schema': 'http://json-schema.org/draft-04/schema#', properties: {} }
          }
        }
      }
    }
  end
  let(:catalog_with_no_plans) do
    {
      services: [
        {
          id: 'service-guid-here',
          name: service_name,
          description: 'A MySQL-compatible relational database',
          bindable: true,
          plans: [{}]
        }
      ]
    }
  end

  let(:catalog_with_small_plan) do
    {
      services: [
        {
          id: 'service-guid-here',
          name: service_name,
          description: 'A MySQL-compatible relational database',
          bindable: true,
          plans: [
            {
              id: 'plan1-guid-here',
              name: 'small',
              description: 'A small shared database with 100mb storage quota and 10 connections'
            }
          ]
        }
      ]
    }
  end

  let(:catalog_with_large_plan) do
    {
      services: [
        {
          id: 'service-guid-here',
          name: service_name,
          description: 'A MySQL-compatible relational database',
          bindable: true,
          plans: [
            {
              id: 'plan2-guid-here',
              name: 'large',
              description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections'
            }
          ]
        }
      ]
    }
  end

  let(:catalog_with_two_plans) do
    {
      services: [
        {
          id: 'service-guid-here',
          name: service_name,
          description: 'A MySQL-compatible relational database',
          bindable: true,
          plans: [
            {
              id: 'plan1-guid-here',
              name: 'small',
              description: 'A small shared database with 100mb storage quota and 10 connections'
            }, {
              id: 'plan2-guid-here',
              name: 'large',
              description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections'
            }
          ]
        }
      ]
    }
  end

  before(:each) { setup_cc }

  def build_service(attrs={})
    @index ||= 0
    @index += 1
    {
      id: SecureRandom.uuid,
      name: "service-#{@index}",
      description: 'A service, duh!',
      bindable: true,
      plans: [
        {
          id: "plan-#{@index}",
          name: "plan-#{@index}",
          description: 'A plan, duh!'
        }
      ]
    }.merge(attrs)
  end

  describe 'on registration' do
    context 'when a service has no plans' do
      before do
        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'MySQL',
              description: 'A MySQL service, duh!',
              bindable: true,
              plans: []
            }
          ]
        })
      end

      it 'notifies the operator of the problem' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        expect(last_response.status).to eql(502)
        expect(decoded_response['code']).to eql(270012)
        expect(decoded_response['description']).to eql("Service broker catalog is invalid: \nService MySQL\n  At least one plan is required\n")
      end
    end

    context 'when there are multiple validation problems in the catalog' do
      before do
        stub_catalog_fetch(200, {
          services: [
            {
              id: 12345,
              name: 'service-1',
              description: 'A' * 10_001,
              bindable: true,
              bindings_retrievable: 'not-a-bool',
              instances_retrievable: 'not-a-bool',
              allow_context_updates: 'not-a-bool',
              plans: [
                {
                  id: 'plan-1',
                  name: 'small',
                  description: 'B' * 10_001,
                  schemas: {
                    service_instance: {
                      create: {
                        parameters: { '$schema': 'http://json-schema.org/draft-04/schema#', properties: true }
                      }
                    }
                  }
                }, {
                  id: 'plan-2',
                  name: 'large',
                  description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections'
                }
              ]
            },
            {
              id: '67890',
              name: 'service-2',
              description: 'Another service, duh!',
              bindable: true,
              plans: [
                {
                  id: 'plan-b',
                  name: 'small',
                  description: 'A small shared database with 100mb storage quota and 10 connections'
                }, {
                  id: 'plan-b',
                  name: 'large',
                  description: ''
                }
              ]
            },
            {
              id: '67890',
              name: 'service-3',
              description: 'Yet another service, duh!',
              bindable: true,
              dashboard_client: {
                id: 'client-1'
              },
              plans: [
                {
                  id: 123,
                  name: 'tiny',
                  description: 'A small shared database with 100mb storage quota and 10 connections'
                }, {
                  id: '456',
                  name: 'tiny',
                  description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections'
                }
              ]
            },
            {
              id: '987654',
              name: 'service-4',
              description: 'Yet another service, duh!',
              bindable: true,
              dashboard_client: {
                id: 'client-1',
                secret: 'no-one-knows',
                redirect_uri: 'http://example.com/client-1'
              },
              plans: []
            },
            {
              id: '888444',
              name: 'service-4',
              description: 'Yet another service, duh!',
              bindable: true,
              dashboard_client: {
                id: 'client-9',
                secret: 'some-secret',
                redirect_uri: 'http://example.com/client-1'
              },
              plans: [
                {
                  id: '999',
                  name: 'micro',
                  description: 'The smallest plan in the world'
                }
              ]
            }
          ]
        })
      end

      it 'notifies the operator of the problem' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        expect(last_response.status).to eql(502)
        expect(decoded_response['code']).to eql(270012)
        expect(decoded_response['description']).to eql(
          "Service broker catalog is invalid: \n" \
          "Service ids must be unique\n" \
          "Service names must be unique within a broker\n" \
          "Plan ids must be unique. Unable to register plan with id 'plan-b' (plan name 'large', " \
          "service name 'service-2') because it uses the same id as another plan in the catalog " \
          "(plan name 'small', service name 'service-2')\n" \
          "Service dashboard_client id must be unique\n" \
          "Service service-1\n" \
          "  Service id must be a string, but has value 12345\n" \
          "  Service description may not have more than 10000 characters\n" \
          "  Service \"bindings_retrievable\" field must be a boolean, but has value \"not-a-bool\"\n" \
          "  Service \"instances_retrievable\" field must be a boolean, but has value \"not-a-bool\"\n" \
          "  Service \"allow_context_updates\" field must be a boolean, but has value \"not-a-bool\"\n" \
          "  Plan small\n" \
          "    Plan description may not have more than 10000 characters\n" \
          "    Schemas\n" \
          '      Schema service_instance.create.parameters is not valid. Must conform to JSON Schema Draft 04 (experimental support for later versions): '\
          "The property '#/properties' of type boolean did not match the following type: object in schema "\
          "http://json-schema.org/draft-04/schema#\n" \
          "Service service-2\n" \
          "  Plan ids must be unique. Service service-2 already has a plan with id 'plan-b'\n" \
          "  Plan large\n" \
          "    Plan description is required\n" \
          "Service service-3\n" \
          "  Service dashboard client secret is required\n" \
          "  Service dashboard client redirect_uri is required\n" \
          "  Plan names must be unique within a service. Service service-3 already has a plan named tiny\n" \
          "  Plan tiny\n" \
          "    Plan id must be a string, but has value 123\n" \
          "Service service-4\n" \
          "  At least one plan is required\n"
                                                   )
      end
    end

    context 'when a plan has a free field in the catalog' do
      before do
        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'service-1',
              description: 'A service, duh!',
              bindable: true,
              plans: [
                {
                  id: 'plan-1',
                  name: 'not-free-plan',
                  description: 'A not free plan',
                  free: false
                }, {
                  id: 'plan-2',
                  name: 'free-plan',
                  description: 'A free plan',
                  free: true
                }
              ]
            }
          ]
        })

        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
      end

      it 'sets the cc plan free field' do
        get('/v2/service_plans', {}.to_json, admin_headers)

        resources = JSON.parse(last_response.body)['resources']
        not_free_plan = resources.find { |plan| plan['entity']['name'] == 'not-free-plan' }
        free_plan = resources.find { |plan| plan['entity']['name'] == 'free-plan' }

        expect(free_plan['entity']['free']).to be true
        expect(not_free_plan['entity']['free']).to be false
      end
    end

    context 'when the CC dashboard_client feature is disabled and the catalog requests a client' do
      let(:service) { build_service(dashboard_client: { id: 'client-id', secret: 'shhhhh', redirect_uri: 'http://example.com/client-id' }) }

      before do
        TestConfig.override(uaa_client_name: nil, uaa_client_secret: nil)

        stub_catalog_fetch(200, services: [service])
      end

      it 'returns a warning' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        warning = CGI.unescape(last_response.headers['X-Cf-Warnings'])
        expect(warning).to eq(VCAP::Services::SSO::DashboardClientManager::REQUESTED_FEATURE_DISABLED_WARNING)
      end

      it 'does not create any dashboard clients' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        expect(VCAP::CloudController::ServiceDashboardClient.count).to eq(0)
      end
    end

    context 'when a schema' do
      [
        { type: 'service_instance', actions: ['create', 'update'] },
        { type: 'service_binding', actions: ['create'] },
      ].each do |test|
        test[:actions].each do |schema_action|
          context "of type #{test[:type]} and action #{schema_action} is not present" do
            {
              "#{schema_action} is nil": { test[:type] => { schema_action => nil } },
              "#{schema_action} is nil": { test[:type] => { schema_action => { 'parameters' => nil } } },
              "#{schema_action} is empty object": { test[:type] => { schema_action => {} } },
            }.each do |desc, schema|
              context "#{desc} #{schema}" do
                before do
                  stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
                end
                it 'succeeds' do
                  post('/v2/service_brokers', {
                    name: 'some-guid',
                    broker_url: 'http://broker-url',
                    auth_username: 'username',
                    auth_password: 'password'
                  }.to_json, admin_headers)

                  expect(last_response.status).to eql(201)
                end
              end
            end
          end

          context "of type #{test[:type]} and action #{schema_action} has a valid schema" do
            let(:schema) { { (test[:type]).to_s => { schema_action => { 'parameters' => { '$schema': 'http://json-schema.org/draft-04/schema#', type: 'object' } } } } }

            before do
              stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
            end

            it 'succeeds' do
              post('/v2/service_brokers', {
                name: 'some-guid',
                broker_url: 'http://broker-url',
                auth_username: 'username',
                auth_password: 'password'
              }.to_json, admin_headers)

              expect(last_response.status).to eql(201)
            end
          end

          context "of type #{test[:type]} and action #{schema_action} is not a JSON object" do
            {
              "#{test[:type]}.#{schema_action}": { (test[:type]).to_s => { schema_action => true } },
              "#{test[:type]}.#{schema_action}.parameters": { (test[:type]).to_s => { schema_action => { 'parameters' => true } } },
            }.each do |path, schema|
              context "operator receives an error about #{path} #{schema}" do
                before do
                  stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
                end
                it 'rejects the request' do
                  post('/v2/service_brokers', {
                    name: 'some-guid',
                    broker_url: 'http://broker-url',
                    auth_username: 'username',
                    auth_password: 'password'
                  }.to_json, admin_headers)

                  expect(last_response.status).to eql(502)
                  expect(decoded_response['code']).to eql(270012)
                  expect(decoded_response['description']).to eql(
                    "Service broker catalog is invalid: \n" \
                    "Service MySQL\n" \
                    "  Plan small\n" \
                    "    Schemas\n" \
                    "      Schemas #{path} must be a hash, but has value true\n")
                end
              end
            end
          end

          context "of type #{test[:type]} and action #{schema_action} does not conform to JSON Schema Draft 04 (experimental support for later versions)" do
            let(:path) { "#{test[:type]}.#{schema_action}.parameters" }
            let(:schema) { { (test[:type]).to_s => { schema_action => { 'parameters' => { '$schema': 'http://json-schema.org/draft-04/schema#', properties: true } } } } }

            before do
              stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
            end

            it 'rejects the request' do
              post('/v2/service_brokers', {
                name: 'some-guid',
                broker_url: 'http://broker-url',
                auth_username: 'username',
                auth_password: 'password'
              }.to_json, admin_headers)

              expect(last_response.status).to eql(502)
              expect(decoded_response['code']).to eql(270012)
              expect(decoded_response['description']).to eql(
                "Service broker catalog is invalid: \n" \
                "Service MySQL\n" \
                "  Plan small\n" \
                "    Schemas\n" \
                "      Schema #{path} is not valid. Must conform to JSON Schema Draft 04 (experimental support for later versions): The property '#/properties' " \
                "of type boolean did not match the following type: object in schema http://json-schema.org/draft-04/schema#\n")
            end
          end

          context "of type #{test[:type]} and action #{schema_action} does not conform to JSON Schema Draft 04 (experimental support for later versions) with multiple problems" do
            let(:path) { "#{test[:type]}.#{schema_action}.parameters" }
            let(:schema) {
              {
                (test[:type]).to_s => {
                  schema_action => {
                    'parameters' => {
                      '$schema': 'http://json-schema.org/draft-04/schema#',
                      properties: true,
                      anyOf: true }
                  }
                }
              }
            }

            before do
              stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
            end
            it 'responds with invalid' do
              post('/v2/service_brokers', {
                name: 'some-guid',
                broker_url: 'http://broker-url',
                auth_username: 'username',
                auth_password: 'password'
              }.to_json, admin_headers)

              expect(last_response.status).to eql(502)
              expect(decoded_response['code']).to eql(270012)
              expect(decoded_response['description']).to eql(
                "Service broker catalog is invalid: \n" \
                "Service MySQL\n" \
                "  Plan small\n" \
                "    Schemas\n" \
                "      Schema #{path} is not valid. Must conform to JSON Schema Draft 04 (experimental support for later versions): The property '#/properties' " \
                "of type boolean did not match the following type: object in schema http://json-schema.org/draft-04/schema#\n"\
                "      Schema #{path} is not valid. Must conform to JSON Schema Draft 04 (experimental support for later versions): The property '#/anyOf' " \
                "of type boolean did not match the following type: array in schema http://json-schema.org/draft-04/schema#\n")
            end
          end

          context "of type #{test[:type]} and action #{schema_action} has an external schema" do
            let(:path) { "#{test[:type]}.#{schema_action}.parameters" }
            let(:schema) { { (test[:type]).to_s => { schema_action => { 'parameters' => { '$schema': 'http://example.com/schema', type: 'object' } } } } }

            before do
              stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
            end

            it 'responds with invalid' do
              post('/v2/service_brokers', {
                name: 'some-guid',
                broker_url: 'http://broker-url',
                auth_username: 'username',
                auth_password: 'password'
              }.to_json, admin_headers)

              expect(last_response.status).to eql(502)
              expect(decoded_response['code']).to eql(270012)
              expect(decoded_response['description']).to eql(
                "Service broker catalog is invalid: \n" \
                "Service MySQL\n" \
                "  Plan small\n" \
                "    Schemas\n" \
                "      Schema #{path} is not valid. Custom meta schemas are not supported.\n"
                                                         )
            end
          end

          context "of type #{test[:type]} and action #{schema_action} has an external uri reference" do
            let(:path) { "#{test[:type]}.#{schema_action}.parameters" }
            let(:schema) {
              {
                (test[:type]).to_s => {
                  schema_action => {
                    'parameters' => {
                      '$schema': 'http://json-schema.org/draft-04/schema#',
                      '$ref': 'http://example.com/ref'
                    }
                  }
                }
              }
            }

            before do
              stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
            end
            it 'responds with invalid' do
              post('/v2/service_brokers', {
                name: 'some-guid',
                broker_url: 'http://broker-url',
                auth_username: 'username',
                auth_password: 'password'
              }.to_json, admin_headers)

              expect(last_response.status).to eql(502)
              expect(decoded_response['code']).to eql(270012)
              expect(decoded_response['description']).to eql(
                "Service broker catalog is invalid: \n" \
                "Service MySQL\n" \
                "  Plan small\n" \
                "    Schemas\n" \
                "      Schema #{path} is not valid. No external references are allowed: Read of URI at http://example.com/ref refused\n"
                                                         )
            end
          end

          context "of type #{test[:type]} and action #{schema_action} has no $schema" do
            let(:path) { "#{test[:type]}.#{schema_action}.parameters" }
            let(:schema) { { (test[:type]).to_s => { schema_action => { 'parameters' => { type: 'object' } } } } }

            before do
              stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
            end

            it 'responds with invalid' do
              post('/v2/service_brokers', {
                name: 'some-guid',
                broker_url: 'http://broker-url',
                auth_username: 'username',
                auth_password: 'password'
              }.to_json, admin_headers)

              expect(last_response.status).to eql(502)
              expect(decoded_response['code']).to eql(270012)
              expect(decoded_response['description']).to eql(
                "Service broker catalog is invalid: \n" \
                "Service MySQL\n" \
                "  Plan small\n" \
                "    Schemas\n" \
                "      Schema #{path} is not valid. Schema must have $schema key but was not present\n"
                                                         )
            end
          end
        end
      end
    end

    context 'when multiple schemas have validation issues' do
      let(:schema) {
        {
          'service_instance' => {
            'create' => { 'parameters' => { '$schema': 'http://json-schema.org/draft-04/schema#', '$ref': 'http://example.com/create' } },
            'update' => { 'parameters' => { '$schema': 'http://json-schema.org/draft-04/schema#', '$ref': 'http://example.com/update' } }
          },
          'service_binding' => {
            'create' => { 'parameters' => { '$schema': 'http://json-schema.org/draft-04/schema#', '$ref': 'http://example.com/binding' } },
          }
        }
      }

      before do
        stub_catalog_fetch(200, default_catalog(plan_schemas: schema))
      end

      it 'reports all issues' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        expect(last_response.status).to eql(502)
        expect(decoded_response['code']).to eql(270012)
        expect(decoded_response['description']).to eql(
          "Service broker catalog is invalid: \n" \
          "Service MySQL\n" \
          "  Plan small\n" \
          "    Schemas\n" \
          "      Schema service_instance.create.parameters is not valid. No external references are allowed: Read of URI at http://example.com/create refused\n" \
          "      Schema service_instance.update.parameters is not valid. No external references are allowed: Read of URI at http://example.com/update refused\n" \
          "      Schema service_binding.create.parameters is not valid. No external references are allowed: Read of URI at http://example.com/binding refused\n"
                                                   )
      end
    end

    context 'when multiple schemas appear in multiple plans for multiple services' do
      let(:schema) {
        {
          'service_instance' => {
            'create' => { 'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#' } },
            'update' => { 'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#' } }
          },
          'service_binding' => {
            'create' => { 'parameters' => { '$schema' => 'http://json-schema.org/draft-04/schema#' } },
          }
        }
      }

      let(:catalog_with_two_services_two_plans_schemas) do
        {
          services:
            [
              {
                id: 'service-guid-here',
                name: service_name,
                description: 'A MySQL-compatible relational database',
                bindable: true,
                plans: [
                  {
                    id: 'plan1-guid-here',
                    name: 'plan1',
                    description: 'A small shared database with 100mb storage quota and 10 connections',
                    schemas: schema
                  }, {
                    id: 'plan2-guid-here',
                    name: 'plan2',
                    description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections',
                    schemas: schema
                  }
                ]
              },
              {
                id: 'service-guid-here-2',
                name: "#{service_name}-2",
                description: 'A MySQL-compatible relational database',
                bindable: true,
                plans: [
                  {
                    id: 'plan3-guid-here',
                    name: 'plan3',
                    description: 'A small shared database with 100mb storage quota and 10 connections',
                    schemas: schema
                  }, {
                    id: 'plan4-guid-here',
                    name: 'plan4',
                    description: 'A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections',
                    schemas: schema
                  }
                ]
              }
            ]
        }
      end

      before do
        stub_catalog_fetch(200, catalog_with_two_services_two_plans_schemas)
        post('/v2/service_brokers',
             { name: 'broker-name', broker_url: 'http://broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
             admin_headers)
      end

      it 'registers all schemas successfully' do
        expect(last_response.status).to eq(201)
        get('/v2/service_plans', {}.to_json, admin_headers)
        resources = JSON.parse(last_response.body)['resources']

        expect(resources.length).to eq(4)

        resources.each do |plan|
          expect(plan['entity']['schemas']).to eq(schema)
        end
      end
    end

    context 'when a service broker already exists with the same URL' do
      before do
        stub_catalog_fetch(200, catalog_with_small_plan)

        post('/v2/service_brokers', {
          name: 'some-broker',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
      end

      it 'fails when the provided broker name is the same' do
        post('/v2/service_brokers', {
          name: 'some-broker',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
        expect(last_response.status).to eql(400)
        expect(decoded_response['code']).to eql(270002)
        expect(decoded_response['description']).to eql('The service broker name is taken')
      end

      it 'succeeds when the provided broker name is different' do
        post('/v2/service_brokers', {
          name: 'some-other-broker',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
        expect(last_response.status).to eql(201)
      end
    end

    context 'when a service broker already exists with a different URL but the same catalog' do
      before do
        stub_catalog_fetch(200, catalog_with_small_plan, 'broker-url')
        stub_catalog_fetch(200, catalog_with_small_plan, 'different-broker-url')

        post('/v2/service_brokers', {
          name: 'some-broker',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
        expect(last_response).to have_status_code(201)
      end

      it 'succeeds when the provided broker name is different' do
        post('/v2/service_brokers', {
          name: 'some-other-broker',
          broker_url: 'http://different-broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
        expect(last_response).to have_status_code(201)
      end

      it 'fails when the provided broker name is the same' do
        post('/v2/service_brokers', {
          name: 'some-broker',
          broker_url: 'http://different-broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
        expect(last_response).to have_status_code(400)
        expect(decoded_response['code']).to eql(270002)
        expect(decoded_response['description']).to eql('The service broker name is taken')
      end
    end

    context 'when a service broker already exists with the same dashboard_client client_id' do
      before do
        UAARequests.stub_all
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-1}).to_return(status: 404)
        stub_catalog_fetch(200, catalog_with_small_plan)

        post('/v2/service_brokers', {
          name: 'some-broker',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
        expect(last_response).to have_status_code(201)
      end

      it 'fails with a uniqueness error' do
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-1}).to_return(
          body: { client_id: 'client-1' }.to_json,
          status: 200,
          headers: { 'content-type' => 'application/json' })

        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'MySQL',
              description: 'A MySQL service, duh!',
              bindable: true,
              plans: [small_plan],
              dashboard_client: { id: 'client-1', secret: 'shhhhh', redirect_uri: 'http://example.com/client-id' }
            }
          ]
        }, 'some-other-broker-url')

        post('/v2/service_brokers', {
          name: 'some-other-broker',
          broker_url: 'http://some-other-broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        expect(last_response).to have_status_code(502)
        expect(decoded_response['code']).to eql(270012)
        expect(decoded_response['description']).to match('Service dashboard client id must be unique')
      end
    end
  end

  describe 'updating a service broker' do
    context 'when the dashboard_client values for a service have changed' do
      let(:service_1) { build_service(dashboard_client: { id: 'client-1', secret: 'shhhhh', redirect_uri: 'http://example.com/client-1' }) }
      let(:service_2) { build_service(dashboard_client: { id: 'client-2', secret: 'sekret', redirect_uri: 'http://example.com/client-2' }) }
      let(:service_3) { build_service(dashboard_client: { id: 'client-3', secret: 'unguessable', redirect_uri: 'http://example.com/client-3' }) }
      let(:service_4) { build_service }
      let(:service_5) { build_service(dashboard_client: { id: 'client-5', secret: 'secret5', redirect_uri: 'http://example.com/client-5' }) }
      let(:service_6) { build_service(dashboard_client: { id: 'client-6', secret: 'secret6', redirect_uri: 'http://example.com/client-6' }) }

      before do
        # set up a fake broker catalog that includes dashboard_client for services
        stub_catalog_fetch(200, services: [service_1, service_2, service_3, service_4, service_5, service_6])
        UAARequests.stub_all
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/.*}).to_return(status: 404)

        # add that broker to the CC
        post('/v2/service_brokers',
             {
               name: 'broker_name',
               broker_url: stubbed_broker_url,
               auth_username: stubbed_broker_username,
               auth_password: stubbed_broker_password
             }.to_json,
             admin_headers
        )
        expect(last_response).to have_status_code(201)
        @service_broker_guid = decoded_response.fetch('metadata').fetch('guid')

        WebMock.reset!

        UAARequests.stub_all
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/.*}).to_return(status: 404)
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-1}).to_return(
          body: { client_id: 'client-1' }.to_json,
          status: 200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-2}).to_return(
          body: { client_id: 'client-2' }.to_json,
          status: 200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-3}).to_return(
          body: { client_id: 'client-3' }.to_json,
          status: 200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-5}).to_return(
          body: { client_id: 'client-5' }.to_json,
          status: 200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-6}).to_return(
          body: { client_id: 'client-6' }.to_json,
          status: 200,
          headers: { 'content-type' => 'application/json' })

        # delete client
        service_1.delete(:dashboard_client)
        # change client id - should result in a delete and a create
        service_2[:dashboard_client][:id] = 'different-client'
        # change client secret - should post to /clients/<client-id>/secret
        service_3[:dashboard_client][:secret] = 'SUPERsecret'
        # add client
        service_4[:dashboard_client] = { id: 'client-4', secret: '1337', redirect_uri: 'http://example.com/client-4' }
        # change property other than ID or secret
        service_5[:dashboard_client][:redirect_uri] = 'http://nowhere.net'

        stub_catalog_fetch(200, services: [service_1, service_2, service_3, service_4, service_5, service_6])

        stub_request(:post, %r{https://uaa.service.cf.internal/oauth/clients/tx/modify}).
          to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: ''
          )
      end

      it 'sends the correct batch request to create/update/delete clients' do
        put("/v2/service_brokers/#{@service_broker_guid}", '{}', admin_headers)

        expect(last_response).to have_status_code(200)

        expected_client_modifications = [
          { # client deleted
            'client_id' => 'client-1',
            'client_secret' => nil,
            'redirect_uri' => nil,
            'scope' => ['openid', 'cloud_controller_service_permissions.read'],
            'authorities' => ['uaa.resource'],
            'authorized_grant_types' => ['authorization_code'],
            'action' => 'delete'
          },
          { # client id renamed to 'different-client'
            'client_id' => 'client-2',
            'client_secret' => nil,
            'redirect_uri' => nil,
            'scope' => ['openid', 'cloud_controller_service_permissions.read'],
            'authorities' => ['uaa.resource'],
            'authorized_grant_types' => ['authorization_code'],
            'action' => 'delete'
          },
          { # client id renamed from 'client-2'
            'client_id' => 'different-client',
            'client_secret' => service_2[:dashboard_client][:secret],
            'redirect_uri' => service_2[:dashboard_client][:redirect_uri],
            'scope' => ['openid', 'cloud_controller_service_permissions.read'],
            'authorities' => ['uaa.resource'],
            'authorized_grant_types' => ['authorization_code'],
            'action' => 'add'
          },
          { # client secret updated
            'client_id' => service_3[:dashboard_client][:id],
            'client_secret' => 'SUPERsecret',
            'redirect_uri' => service_3[:dashboard_client][:redirect_uri],
            'scope' => ['openid', 'cloud_controller_service_permissions.read'],
            'authorities' => ['uaa.resource'],
            'authorized_grant_types' => ['authorization_code'],
            'action' => 'update,secret'
          },
          { # newly added client
            'client_id' => service_4[:dashboard_client][:id],
            'client_secret' => service_4[:dashboard_client][:secret],
            'redirect_uri' => service_4[:dashboard_client][:redirect_uri],
            'scope' => ['openid', 'cloud_controller_service_permissions.read'],
            'authorities' => ['uaa.resource'],
            'authorized_grant_types' => ['authorization_code'],
            'action' => 'add'
          },
          { # client redirect_uri updated
            'client_id' => service_5[:dashboard_client][:id],
            'client_secret' => service_5[:dashboard_client][:secret],
            'redirect_uri' => 'http://nowhere.net',
            'scope' => ['openid', 'cloud_controller_service_permissions.read'],
            'authorities' => ['uaa.resource'],
            'authorized_grant_types' => ['authorization_code'],
            'action' => 'update,secret'
          },
          { # no change
            'client_id' => service_6[:dashboard_client][:id],
            'client_secret' => service_6[:dashboard_client][:secret],
            'redirect_uri' => service_6[:dashboard_client][:redirect_uri],
            'scope' => ['openid', 'cloud_controller_service_permissions.read'],
            'authorities' => ['uaa.resource'],
            'authorized_grant_types' => ['authorization_code'],
            'action' => 'update,secret'
          }
        ]

        expect(a_request(:post, 'https://uaa.service.cf.internal/oauth/clients/tx/modify').with do |req|
          client_modifications = JSON.parse(req.body)
          expect(client_modifications).to match_array(expected_client_modifications)
        end).to have_been_made
      end

      it 'can update the service broker name' do
        put("/v2/service_brokers/#{@service_broker_guid}", '{"name":"new_broker_name"}',
            admin_headers)

        expect(last_response).to have_status_code(200)

        parsed_body = JSON.parse(last_response.body)
        expect(parsed_body['entity']['name']).to eq('new_broker_name')
      end
    end

    context 'when the free field for a plan has changed' do
      before do
        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'service-1',
              description: 'A service, duh!',
              bindable: true,
              plans: [
                {
                  id: 'plan-1',
                  name: 'not-free-plan',
                  description: 'A not free plan',
                  free: false
                }, {
                  id: 'plan-2',
                  name: 'free-plan',
                  description: 'A free plan',
                  free: true
                }
              ]
            }
          ]
        })

        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        guid = VCAP::CloudController::ServiceBroker.first.guid

        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'service-1',
              description: 'A service, duh!',
              bindable: true,
              plans: [
                {
                  id: 'plan-1',
                  name: 'not-free-plan',
                  description: 'A not free plan',
                  free: true
                }, {
                  id: 'plan-2',
                  name: 'free-plan',
                  description: 'A free plan',
                  free: false
                }
              ]
            }
          ]
        })

        put("/v2/service_brokers/#{guid}", {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
      end

      it 'sets the cc plan free field' do
        get('/v2/service_plans', {}.to_json, admin_headers)

        resources = JSON.parse(last_response.body)['resources']
        no_longer_not_free_plan = resources.find { |plan| plan['entity']['name'] == 'not-free-plan' }
        no_longer_free_plan = resources.find { |plan| plan['entity']['name'] == 'free-plan' }

        expect(no_longer_free_plan['entity']['free']).to be false
        expect(no_longer_not_free_plan['entity']['free']).to be true
      end
    end

    context 'when the allow_context_updates field for a service has changed' do
      before do
        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'allow-context-updates-service',
              description: 'A service, duh!',
              bindable: true,
              bindings_retrievable: true,
              allow_context_updates: true,
              plans: [
                {
                  id: 'plan-1',
                  name: 'random-name-1',
                  description: 'A not free plan',
                }
              ]
            }, {
              id: '123456',
              name: 'not-allow-context-updates-service',
              description: 'A service, duh!',
              bindable: true,
              bindings_retrievable: false,
              allow_context_updates: false,
              plans: [
                {
                  id: 'plan-2',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }, {
              id: '1234567',
              name: 'allow-context-updates-service-will-be-unset',
              description: 'A service, duh!',
              bindable: true,
              bindings_retrievable: true,
              allow_context_updates: true,
              plans: [
                {
                  id: 'plan-3',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }
          ]
        })

        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        guid = VCAP::CloudController::ServiceBroker.first.guid

        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'allow-context-updates-service',
              description: 'A service, duh!',
              bindable: true,
              bindings_retrievable: false,
              allow_context_updates: false,
              plans: [
                {
                  id: 'plan-1',
                  name: 'random-name-1',
                  description: 'A not free plan',
                }
              ]
            },
            {
              id: '123456',
              name: 'not-allow-context-updates-service',
              description: 'a service, duh!',
              bindable: true,
              bindings_retrievable: true,
              allow_context_updates: true,
              plans: [
                {
                  id: 'plan-2',
                  name: 'random-name-2',
                  description: 'a not free plan',
                }
              ]
            }, {
              id: '1234567',
              name: 'allow-context-updates-service-will-be-unset',
              description: 'A service, duh!',
              bindable: true,
              plans: [
                {
                  id: 'plan-3',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }]
        })

        put("/v2/service_brokers/#{guid}", {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
      end

      it 'sets the cc service allow_context_updates field' do
        get('/v2/services', {}.to_json, admin_headers)
        expect(last_response).to have_status_code(200)

        resources = JSON.parse(last_response.body)['resources']

        no_longer_allow_context_updates_service = resources.find { |service| service['entity']['label'] == 'allow-context-updates-service' }
        now_allow_context_updates_service = resources.find { |service| service['entity']['label'] == 'not-allow-context-updates-service' }
        unset_allow_context_updates_service = resources.find { |service| service['entity']['label'] == 'allow-context-updates-service-will-be-unset' }

        expect(no_longer_allow_context_updates_service['entity']['allow_context_updates']).to be false
        expect(now_allow_context_updates_service['entity']['allow_context_updates']).to be true
        expect(unset_allow_context_updates_service['entity']['allow_context_updates']).to be false
      end
    end

    context 'when the bindings_retrievable field for a service has changed' do
      before do
        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'bindings-retrievable-service',
              description: 'A service, duh!',
              bindable: true,
              bindings_retrievable: true,
              plans: [
                {
                  id: 'plan-1',
                  name: 'random-name-1',
                  description: 'A not free plan',
                }
              ]
            }, {
              id: '123456',
              name: 'bindings-not-retrievable-service',
              description: 'A service, duh!',
              bindable: true,
              bindings_retrievable: false,
              plans: [
                {
                  id: 'plan-2',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }, {
              id: '1234567',
              name: 'bindings-retrievable-service-will-be-unset',
              description: 'A service, duh!',
              bindable: true,
              bindings_retrievable: true,
              plans: [
                {
                  id: 'plan-3',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }
          ]
        })

        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        guid = VCAP::CloudController::ServiceBroker.first.guid

        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'bindings-retrievable-service',
              description: 'A service, duh!',
              bindable: true,
              bindings_retrievable: false,
              plans: [
                {
                  id: 'plan-1',
                  name: 'random-name-1',
                  description: 'A not free plan',
                }
              ]
            },
            {
              id: '123456',
              name: 'bindings-not-retrievable-service',
              description: 'a service, duh!',
              bindable: true,
              bindings_retrievable: true,
              plans: [
                {
                  id: 'plan-2',
                  name: 'random-name-2',
                  description: 'a not free plan',
                }
              ]
            }, {
              id: '1234567',
              name: 'bindings-retrievable-service-will-be-unset',
              description: 'A service, duh!',
              bindable: true,
              plans: [
                {
                  id: 'plan-3',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }]
        })

        put("/v2/service_brokers/#{guid}", {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
      end

      it 'sets the cc service bindings_retrievable field' do
        get('/v2/services', {}.to_json, admin_headers)

        resources = JSON.parse(last_response.body)['resources']

        no_longer_bindings_retrievable_service = resources.find { |service| service['entity']['label'] == 'bindings-retrievable-service' }
        now_bindings_retrievable_service = resources.find { |service| service['entity']['label'] == 'bindings-not-retrievable-service' }
        unset_bindings_retrievable_service = resources.find { |service| service['entity']['label'] == 'bindings-retrievable-service-will-be-unset' }

        expect(no_longer_bindings_retrievable_service['entity']['bindings_retrievable']).to be false
        expect(now_bindings_retrievable_service['entity']['bindings_retrievable']).to be true
        expect(unset_bindings_retrievable_service['entity']['bindings_retrievable']).to be false
      end
    end

    context 'when the instances_retrievable field for a service has changed' do
      before do
        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'instances-retrievable-service',
              description: 'A service, duh!',
              bindable: true,
              instances_retrievable: true,
              plans: [
                {
                  id: 'plan-1',
                  name: 'random-name-1',
                  description: 'A not free plan',
                }
              ]
            }, {
              id: '123456',
              name: 'instances-not-retrievable-service',
              description: 'A service, duh!',
              bindable: true,
              instances_retrievable: false,
              plans: [
                {
                  id: 'plan-2',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }, {
              id: '1234567',
              name: 'instances-retrievable-service-will-be-unset',
              description: 'A service, duh!',
              bindable: true,
              instances_retrievable: true,
              plans: [
                {
                  id: 'plan-3',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }
          ]
        })

        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)

        guid = VCAP::CloudController::ServiceBroker.first.guid

        stub_catalog_fetch(200, {
          services: [
            {
              id: '12345',
              name: 'instances-retrievable-service',
              description: 'A service, duh!',
              bindable: true,
              instances_retrievable: false,
              plans: [
                {
                  id: 'plan-1',
                  name: 'random-name-1',
                  description: 'A not free plan',
                }
              ]
            },
            {
              id: '123456',
              name: 'instances-not-retrievable-service',
              description: 'a service, duh!',
              bindable: true,
              instances_retrievable: true,
              plans: [
                {
                  id: 'plan-2',
                  name: 'random-name-2',
                  description: 'a not free plan',
                }
              ]
            }, {
              id: '1234567',
              name: 'instances-retrievable-service-will-be-unset',
              description: 'A service, duh!',
              bindable: true,
              plans: [
                {
                  id: 'plan-3',
                  name: 'random-name-2',
                  description: 'A not free plan',
                }
              ]
            }
          ]
        })

        put("/v2/service_brokers/#{guid}", {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, admin_headers)
      end

      it 'sets the cc service instances_retrievable field' do
        get('/v2/services', {}.to_json, admin_headers)

        resources = JSON.parse(last_response.body)['resources']

        no_longer_instances_retrievable_service = resources.find { |service| service['entity']['label'] == 'instances-retrievable-service' }
        now_instances_retrievable_service = resources.find { |service| service['entity']['label'] == 'instances-not-retrievable-service' }
        unset_instances_retrievable_service = resources.find { |service| service['entity']['label'] == 'instances-retrievable-service-will-be-unset' }

        expect(no_longer_instances_retrievable_service['entity']['instances_retrievable']).to be false
        expect(now_instances_retrievable_service['entity']['instances_retrievable']).to be true
        expect(unset_instances_retrievable_service['entity']['instances_retrievable']).to be false
      end
    end

    context 'when a plan is re-named, and another plan is added to the front of the list of plans with the old name' do
      let(:catalog1) do
        {
          services: [
            {
              id: 'service-guid-here',
              name: service_name,
              description: 'A MySQL-compatible relational database',
              bindable: true,
              plans: [
                {
                  id: 'plan1-guid-here',
                  name: 'small',
                  description: 'A small shared database with 100mb storage quota and 10 connections'
                }
              ]
            }
          ]
        }
      end

      let(:catalog2) do
        {
          services: [
            {
              id: 'service-guid-here',
              name: service_name,
              description: 'A MySQL-compatible relational database',
              bindable: true,
              plans: [
                {
                  id: 'plan2-guid-here',
                  name: 'small',
                  description: 'A small shared database with 100mb storage quota and 10 connections'
                }, {
                  id: 'plan1-guid-here',
                  name: 'small-legacy',
                  description: '(Legacy) A small shared database with 100mb storage quota and 10 connections'
                }
              ]
            }
          ]
        }
      end

      it 'renames the plan and adds a new plan with the old name' do
        setup_broker(catalog1)
        update_broker(catalog2)
        expect(last_response).to have_status_code(200)

        expect(VCAP::CloudController::ServicePlan.find(unique_id: 'plan2-guid-here')[:name]).to eq('small')
        expect(VCAP::CloudController::ServicePlan.find(unique_id: 'plan1-guid-here')[:name]).to eq('small-legacy')
      end
    end

    context 'when a service is re-named and another service is added to the front of the list with the old name' do
      let(:catalog1) do
        {
          services: [
            {
              id: 'service-guid-here',
              name: 'mysql',
              description: 'A MySQL-compatible relational database',
              bindable: true,
              plans: [
                {
                  id: 'plan-guid-here',
                  name: 'small',
                  description: 'A small shared database with 100mb storage quota and 10 connections'
                }
              ]
            }
          ]
        }
      end

      let(:catalog2) do
        {
          services: [
            {
              id: 'new-service-guid-here',
              name: 'mysql',
              description: 'A MySQL-compatible relational database',
              bindable: true,
              plans: [
                {
                  id: 'new-plan-guid-here',
                  name: 'small',
                  description: 'A small shared database with 100mb storage quota and 10 connections'
                }
              ]
            },
            {
              id: 'service-guid-here',
              name: 'legacy-mysql',
              description: 'A MySQL-compatible relational database',
              bindable: true,
              plans: [
                {
                  id: 'plan-guid-here',
                  name: 'small',
                  description: 'A small shared database with 100mb storage quota and 10 connections'
                }
              ]
            },
          ]
        }
      end

      it 'renames the plan and adds a new plan with the old name' do
        setup_broker(catalog1)
        update_broker(catalog2)
        expect(last_response).to have_status_code(200)

        expect(VCAP::CloudController::Service.find(unique_id: 'service-guid-here')[:label]).to eq('legacy-mysql')
        expect(VCAP::CloudController::Service.find(unique_id: 'new-service-guid-here')[:label]).to eq('mysql')
      end
    end

    context 'when a service plan disappears from the catalog' do
      before do
        setup_broker(catalog_with_two_plans)
      end

      context 'when it has an existing instance' do
        before do
          provision_service
        end

        it 'the plan should become inactive' do
          update_broker(catalog_with_large_plan)
          expect(last_response).to have_status_code(200)

          expect(VCAP::CloudController::ServicePlan.find(unique_id: 'plan1-guid-here')[:active]).to be false
        end

        it 'returns a warning to the operator' do
          update_broker(catalog_with_large_plan)
          expect(last_response).to have_status_code(200)

          warning = CGI.unescape(last_response.headers['X-Cf-Warnings'])

          expect(warning).to eq(<<~HEREDOC)
            Warning: Service plans are missing from the broker's catalog (http://#{stubbed_broker_host}/v2/catalog) but can not be removed from Cloud Foundry while instances exist. The plans have been deactivated to prevent users from attempting to provision new instances of these plans. The broker should continue to support bind, unbind, and delete for existing instances; if these operations fail contact your broker provider.

            Service Offering: #{service_name}
            Plans deactivated: small
          HEREDOC
        end
      end

      context 'when it has no existing instance' do
        it 'the plan should become inactive' do
          update_broker(catalog_with_large_plan)
          expect(last_response).to have_status_code(200)

          get('/v2/services?inline-relations-depth=1', '{}', admin_headers)
          expect(last_response).to have_status_code(200)

          parsed_body = JSON.parse(last_response.body)
          expect(parsed_body['resources'].first['entity']['service_plans'].length).to eq(1)
        end
      end

      context 'when the service is updated to have no plans' do
        it 'returns an error and does not update the broker' do
          update_broker(catalog_with_no_plans)
          expect(last_response).to have_status_code(502)

          get('/v2/services?inline-relations-depth=1', '{}', admin_headers)
          expect(last_response).to have_status_code(200)

          parsed_body = JSON.parse(last_response.body)
          expect(parsed_body['resources'].first['entity']['service_plans'].length).to eq(2)
        end
      end
    end
  end

  describe 'deleting a service broker' do
    context 'when broker has dashboard clients' do
      let(:service_1) { build_service(dashboard_client: { id: 'client-1', secret: 'shhhhh', redirect_uri: 'http://example.com/client-1' }) }
      let(:service_2) { build_service(dashboard_client: { id: 'client-2', secret: 'sekret', redirect_uri: 'http://example.com/client-2' }) }
      let(:service_3) { build_service }

      before do
        # set up a fake broker catalog that includes dashboard_client for services
        stub_catalog_fetch(200, services: [service_1, service_2, service_3])
        UAARequests.stub_all
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/.*}).to_return(status: 404)

        # add that broker to the CC
        post('/v2/service_brokers',
             {
               name: 'broker_name',
               broker_url: stubbed_broker_url,
               auth_username: stubbed_broker_username,
               auth_password: stubbed_broker_password
             }.to_json,
             admin_headers
        )
        expect(last_response).to have_status_code(201)
        @service_broker_guid = decoded_response.fetch('metadata').fetch('guid')

        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-1}).to_return(
          body: { client_id: 'client-1' }.to_json,
          status: 200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{https://uaa.service.cf.internal/oauth/clients/client-2}).to_return(
          body: { client_id: 'client-2' }.to_json,
          status: 200,
          headers: { 'content-type' => 'application/json' })

        stub_request(:post, %r{https://uaa.service.cf.internal/oauth/clients/tx/modify}).
          to_return(
            status: 200,
            headers: { 'content-type' => 'application/json' },
            body: ''
          )
      end

      it 'deletes the dashboard clients from UAA' do
        delete("/v2/service_brokers/#{@service_broker_guid}", '', admin_headers)
        expect(last_response).to have_status_code(204)

        expected_json_body = [
          {
            client_id: service_1[:dashboard_client][:id],
            client_secret: nil,
            redirect_uri: nil,
            scope: ['openid', 'cloud_controller_service_permissions.read'],
            authorities: ['uaa.resource'],
            authorized_grant_types: ['authorization_code'],
            action: 'delete'
          },
          {
            client_id: service_2[:dashboard_client][:id],
            client_secret: nil,
            redirect_uri: nil,
            scope: ['openid', 'cloud_controller_service_permissions.read'],
            authorities: ['uaa.resource'],
            authorized_grant_types: ['authorization_code'],
            action: 'delete'
          }
        ].to_json

        expect(
          a_request(:post, 'https://uaa.service.cf.internal/oauth/clients/tx/modify').
            with(
              body: expected_json_body
            )).to have_been_made
      end
    end

    context 'when a service instance exists' do
      before do
        setup_broker(catalog_with_small_plan)
        provision_service
      end

      after do
        deprovision_service
        delete_broker
      end

      it 'does not delete the broker', isolation: :truncation do # Can't use transactions for isolation because we're
        # testing a rollback
        delete_broker
        expect(last_response).to have_status_code(400)

        get('/v2/services?inline-relations-depth=1', '{}', admin_headers)
        expect(last_response).to have_status_code(200)

        parsed_body = JSON.parse(last_response.body)
        expect(parsed_body['resources'].first['entity']['label']).to eq(service_name)
        expect(parsed_body['resources'].first['entity']['service_plans'].length).to eq(1)
      end
    end
  end
end

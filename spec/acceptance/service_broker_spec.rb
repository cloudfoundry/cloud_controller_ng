require 'spec_helper'

describe 'Service Broker' do
  before do
    VCAP::CloudController::Controller.any_instance.stub(:in_test_mode?).and_return(false)
  end

  before(:all) { setup_cc }
  after(:all) { $spec_env.reset_database_with_seeds }

  describe 'adding a service broker' do
    context 'when a service has no plans' do
      before do
        stub_catalog_fetch(200, {
          services: [{
            id:          '12345',
            name:        'MySQL',
            description: 'A MySQL service, duh!',
            bindable:    true,
            plans:       []
          }]
        })
      end

      it 'notifies the operator of the problem' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))

        expect(last_response.status).to eql(502)
        expect(decoded_response['code']).to eql(270012)
        expect(decoded_response['description']).to eql("Service broker catalog is invalid: \nService MySQL\n  At least one plan is required\n")
      end
    end

    context 'when there are type mismatches in the catalog' do
      before do
        stub_catalog_fetch(200, {
          services: [{
            id:          12345,
            name:        "MySQL",
            description: "A MySQL service, duh!",
            bindable:    true,
            plans:       [{
              id:          "plan-id",
              name:        "small",
              description: "A small shared database with 100mb storage quota and 10 connections"
            }, {
              id:          "plan2-guid-here",
              name:        "large",
              description: "A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections"
            }]
          }]
        })
      end

      it 'notifies the operator of the problem' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))

        expect(last_response.status).to eql(502)
        expect(decoded_response['code']).to eql(270012)
        expect(decoded_response['description']).to eql("Service broker catalog is invalid: \nService MySQL\n  Service id must be a string, but has value 12345\n")
      end
    end
  end
end

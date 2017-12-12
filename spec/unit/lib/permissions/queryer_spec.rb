require 'securerandom'
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Permissions::Queryer do
    let(:db_permissions) { instance_double(VCAP::CloudController::Permissions) }
    let(:perm_permissions) { instance_double(VCAP::CloudController::Perm::Permissions) }
    let(:perm_enabled) { true }
    let(:query_enabled) { true }
    let(:current_user_guid) { SecureRandom.uuid }

    subject(:queryer) { Permissions::Queryer.new(db_permissions: db_permissions, perm_permissions: perm_permissions, perm_enabled: perm_enabled, query_enabled: query_enabled, current_user_guid: current_user_guid) }

    describe '.build_from_config' do
      it 'makes a new queryer object' do
        configuration = instance_double(VCAP::CloudController::Config)
        file_reader = spy(:file)
        security_context = class_double(VCAP::CloudController::SecurityContext)

        allow(configuration).to receive(:get).with(:perm, :enabled).and_return(true)
        allow(configuration).to receive(:get).with(:perm, :query_enabled).and_return(true)

        roles = instance_double(VCAP::CloudController::Roles)
        allow(security_context).to receive(:roles).and_return(roles)

        issuer = 'some-issuer'
        token = {'iss' => issuer}
        allow(security_context).to receive(:token).and_return(token)

        current_user = spy(:current_user)
        current_user_guid = 'foo'
        allow(security_context).to receive(:current_user_guid).and_return(current_user_guid)
        allow(security_context).to receive(:current_user).and_return(current_user)


        allow(VCAP::CloudController::Permissions).to receive(:new).and_return(db_permissions)

        perm_client = instance_double(Perm::Client)
        allow(Perm::Client).to receive(:build_from_config).and_return(perm_client)

        allow(VCAP::CloudController::Perm::Permissions).to receive(:new).and_return(perm_permissions)


        queryer = Permissions::Queryer.build_from_config(configuration, file_reader, security_context)


        expect(VCAP::CloudController::Perm::Client).to have_received(:build_from_config).with(configuration, file_reader)
        expect(VCAP::CloudController::Permissions).to have_received(:new).with(current_user)
        expect(VCAP::CloudController::Perm::Permissions).to have_received(:new).with(
          perm_client: perm_client,
          roles: roles,
          user_id: current_user_guid,
          issuer: issuer
        )

        expect(queryer.db_permissions).to eq(db_permissions)
        expect(queryer.perm_permissions).to eq(perm_permissions)
        expect(queryer.perm_enabled).to eq(true)
        expect(queryer.query_enabled).to eq(true)
        expect(queryer.current_user_guid).to eq(current_user_guid)
      end
    end

    
  end
end

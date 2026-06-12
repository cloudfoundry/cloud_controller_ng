require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataModel do
    describe 'credentials' do
      let(:app) { AppModel.make }

      context 'when credentials are set' do
        it 'stores and retrieves credentials encrypted' do
          lifecycle_data = BuildpackLifecycleDataModel.create(
            app: app,
            stack: 'docker://docker.io/cloudfoundry/cflinuxfs4:1.0.0',
            buildpacks: ['https://github.com/my-buildpack.git'],
            credentials: { 'docker.io' => { 'username' => 'user', 'password' => 'pass' } }
          )

          reloaded = BuildpackLifecycleDataModel.find(guid: lifecycle_data.guid)
          expect(reloaded.credentials).to eq({ 'docker.io' => { 'username' => 'user', 'password' => 'pass' } })
        end

        it 'redacts credentials in to_hash' do
          lifecycle_data = BuildpackLifecycleDataModel.create(
            app: app,
            stack: 'docker://docker.io/cloudfoundry/cflinuxfs4:1.0.0',
            buildpacks: ['https://github.com/my-buildpack.git'],
            credentials: { 'docker.io' => { 'username' => 'user', 'password' => 'pass' } }
          )

          hash = lifecycle_data.to_hash
          expect(hash[:credentials]).to eq(Presenters::Censorship::REDACTED_CREDENTIAL)
        end
      end

      context 'when credentials are nil' do
        it 'returns nil for credentials' do
          lifecycle_data = BuildpackLifecycleDataModel.create(
            app: app,
            stack: 'cflinuxfs4',
            buildpacks: ['https://github.com/test/bp.git']
          )

          expect(lifecycle_data.credentials).to be_nil
        end

        it 'does not include credentials in to_hash' do
          lifecycle_data = BuildpackLifecycleDataModel.create(
            app: app,
            stack: 'cflinuxfs4',
            buildpacks: ['https://github.com/test/bp.git']
          )

          hash = lifecycle_data.to_hash
          expect(hash).not_to have_key(:credentials)
        end
      end
    end
  end
end

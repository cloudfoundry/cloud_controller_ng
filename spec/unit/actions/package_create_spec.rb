require 'spec_helper'
require 'actions/package_create'

module VCAP::CloudController
  describe PackageCreate do
    let(:package_create) { PackageCreate.new(user, user_email) }

    describe '#create' do
      let(:app) { AppModel.make }
      let(:type) { 'docker' }
      let(:url) { 'docker://cloudfoundry/runtime-ci' }
      let(:app_guid) { app.guid }
      let(:message) { PackageCreateMessage.new({ type: type, url: url, app_guid: app_guid }) }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      it 'creates the package with the correct values' do
        result = package_create.create(message)

        expect(app.packages.first).to eq(result)
        created_package = PackageModel.find(guid: result.guid)
        expect(created_package).to eq(result)
        expect(created_package.type).to eq(type)
        expect(created_package.url).to eq(url)
      end

      it 'creates an audit event' do
        expect(Repositories::Runtime::PackageEventRepository).to receive(:record_app_add_package).with(
            instance_of(PackageModel),
            user,
            user_email,
            {
              'app_guid' => app_guid,
              'type' => type,
              'url' => url,
            }
          )

        package_create.create(message)
      end

      describe 'package state' do
        context 'when type is bits' do
          let(:type) { 'bits' }
          let(:url) { nil }

          it 'sets the state to CREATED_STATE' do
            result = package_create.create(message)
            expect(result.type).to eq('bits')
            expect(result.state).to eq(PackageModel::CREATED_STATE)
          end
        end

        context 'when the type is docker' do
          it 'sets the state to READY_STATE' do
            result = package_create.create(message)
            expect(result.type).to eq('docker')
            expect(result.state).to eq(PackageModel::READY_STATE)
          end
        end
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(PackageModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('the message'))
        end

        it 'raises an InvalidPackage error' do
          expect {
            package_create.create(message)
          }.to raise_error(PackageCreate::InvalidPackage, 'the message')
        end
      end
    end
  end
end

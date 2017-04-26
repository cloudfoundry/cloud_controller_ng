require 'spec_helper'
require 'actions/package_create'

module VCAP::CloudController
  RSpec.describe PackageCreate do
    let(:app) { AppModel.make }
    let(:type) { 'docker' }
    let(:relationships) { { app: { data: { guid: app.guid } } } }
    let(:message) { PackageCreateMessage.new({ type: type, relationships: relationships }) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user_guid, user_email: user_email) }

    describe '#create' do
      let(:user_guid) { 'gooid' }
      let(:user_email) { 'user@example.com' }

      it 'creates the package with the correct values' do
        result = described_class.create(message: message, user_audit_info: user_audit_info)

        expect(app.packages.first).to eq(result)
        created_package = PackageModel.find(guid: result.guid)
        expect(created_package).to eq(result)
        expect(created_package.type).to eq(type)
      end

      it 'creates an audit event' do
        expect(Repositories::PackageEventRepository).to receive(:record_app_package_create).with(
          instance_of(PackageModel),
          user_audit_info,
          {
            'relationships' => relationships,
            'type' => type,
          }
        )

        described_class.create(message: message, user_audit_info: user_audit_info)
      end

      describe 'docker packages' do
        let(:image) { 'registry/image:latest' }
        let(:docker_username) { 'anakin' }
        let(:docker_password) { 'n1k4n4' }
        let(:message) do
          data = {
            type: 'docker',
            relationships: relationships,
            data: {
              image: image,
              username: docker_username,
              password: docker_password
            }
          }
          PackageCreateMessage.new(data)
        end

        it 'persists docker info' do
          result = described_class.create(message: message, user_audit_info: user_audit_info)

          expect(app.packages.first).to eq(result)
          created_package = PackageModel.find(guid: result.guid)

          expect(created_package).to eq(result)
          expect(created_package.image).to eq(image)
          expect(created_package.docker_username).to eq(docker_username)
          expect(created_package.docker_password).to eq(docker_password)
        end

        it 'creates an audit event' do
          expect(Repositories::PackageEventRepository).to receive(:record_app_package_create).with(
            instance_of(PackageModel),
            user_audit_info,
            {
              'relationships' => relationships,
              'type' => type,
              'data' => {
                image: image,
                username: docker_username,
                password: '***'
              }
            }
          )

          described_class.create(message: message, user_audit_info: user_audit_info)
        end
      end

      describe 'package state' do
        context 'when type is bits' do
          let(:type) { 'bits' }
          let(:url) { nil }

          it 'sets the state to CREATED_STATE' do
            result = described_class.create(message: message, user_audit_info: user_audit_info)
            expect(result.type).to eq('bits')
            expect(result.state).to eq(PackageModel::CREATED_STATE)
          end
        end

        context 'when the type is docker' do
          it 'sets the state to READY_STATE' do
            result = described_class.create(message: message, user_audit_info: user_audit_info)
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
            described_class.create(message: message, user_audit_info: user_audit_info)
          }.to raise_error(PackageCreate::InvalidPackage, 'the message')
        end
      end
    end

    describe '#create_without_event' do
      it 'creates the package with the correct values' do
        result = described_class.create_without_event(message)

        expect(app.packages.first).to eq(result)
        created_package = PackageModel.find(guid: result.guid)
        expect(created_package).to eq(result)
        expect(created_package.type).to eq(type)
      end

      it 'does not create an audit event' do
        expect(Repositories::PackageEventRepository).not_to receive(:record_app_package_create)
        described_class.create_without_event(message)
      end
    end
  end
end

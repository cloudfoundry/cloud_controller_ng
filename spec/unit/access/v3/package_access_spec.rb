require 'spec_helper'

module VCAP::CloudController
  describe PackageModelAccess, type: :access do
    let(:token) { {} }
    let(:admin) { false }
    let(:user) { User.make }
    let(:roles) { double(:roles, admin?: admin) }
    let(:package) { PackageModel.make }
    let(:access_context) { double(:access_context, roles: roles, user: user) }

    before do
      SecurityContext.set(nil, token)
    end

    after do
      SecurityContext.clear
    end

    describe '#read?' do
      let(:space) { Space.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }

      context 'admin user' do
        let(:admin) { true }

        it 'allows the user to read' do
          access_control = PackageModelAccess.new(access_context)
          expect(access_control.read?(nil)).to be_truthy
        end
      end

      context 'non admin users' do
        context 'when the user has sufficient scope and permission' do
          let(:token) { { 'scope' => ['cloud_controller.read'] } }

          it 'allows the user to read' do
            allow(Space).to receive(:user_visible).and_return(Space.where(guid: space.guid))
            access_control = PackageModelAccess.new(access_context)
            expect(access_control.read?(package)).to be_truthy
          end
        end

        context 'when the user has insufficient scope' do
          it 'disallows the user from reading' do
            allow(Space).to receive(:user_visible).and_return(Space.where(guid: space.guid))
            access_control = PackageModelAccess.new(access_context)
            expect(access_control.read?(package)).to be_falsey
          end
        end

        context 'when the package is not visible to the user' do
          let(:token) { { 'scope' => ['cloud_controller.read'] } }

          it 'disallows the user from reading' do
            allow(Space).to receive(:user_visible).and_return(Space.where(guid: nil))
            access_control = PackageModelAccess.new(access_context)
            expect(access_control.read?(package)).to be_falsey
          end
        end
      end
    end

    describe '#create?, #delete?, #upload?' do
      let(:space) { Space.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }

      context 'admin user' do
        let(:admin) { true }

        it 'allows the user to perform the action' do
          access_control = PackageModelAccess.new(access_context)
          expect(access_control.create?(package, space)).to be_truthy
          expect(access_control.delete?(package, space)).to be_truthy
          expect(access_control.upload?(package, space)).to be_truthy
        end
      end

      context 'non admin users' do
        context 'when the user has sufficient scope and permissions' do
          let(:token) { { 'scope' => ['cloud_controller.write'] } }

          before do
            space.organization.add_user(user)
            space.add_developer(user)
          end

          it 'allows the user to create' do
            access_control = PackageModelAccess.new(access_context)
            expect(access_control.create?(package, space)).to be_truthy
            expect(access_control.delete?(package, space)).to be_truthy
            expect(access_control.upload?(package, space)).to be_truthy
          end
        end

        context 'when the user has insufficient scope' do
          let(:token) { { 'scope' => ['cloud_controller.read'] } }

          before do
            space.organization.add_user(user)
            space.add_developer(user)
          end

          it 'disallows the user from creating' do
            access_control = PackageModelAccess.new(access_context)
            expect(access_control.create?(package, space)).to be_falsey
            expect(access_control.delete?(package, space)).to be_falsey
            expect(access_control.upload?(package, space)).to be_falsey
          end
        end

        context 'when the user has insufficient permissions' do
          let(:token) { { 'scope' => ['cloud_controller.write'] } }

          it 'disallows the user from creating' do
            access_control = PackageModelAccess.new(access_context)
            expect(access_control.create?(package, space)).to be_falsey
            expect(access_control.delete?(package, space)).to be_falsey
            expect(access_control.upload?(package, space)).to be_falsey
          end
        end

        context 'when the organization is not active' do
          let(:token) { { 'scope' => ['cloud_controller.write'] } }

          before do
            space.organization.add_user(user)
            space.add_developer(user)
            space.organization.update(status: 'suspended')
          end

          it 'disallows the user from creating' do
            access_control = PackageModelAccess.new(access_context)
            expect(access_control.create?(package, space)).to be_falsey
            expect(access_control.delete?(package, space)).to be_falsey
            expect(access_control.upload?(package, space)).to be_falsey
          end
        end
      end
    end

    describe '#upload? when the app_bits_upload feature flag is disabled' do
      let(:space) { Space.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }

      before do
        FeatureFlag.make(name: 'app_bits_upload', enabled: false)
      end

      context 'as an admin user' do
        let(:admin) { true }

        it 'allows the user to upload' do
          access_control = PackageModelAccess.new(access_context)
          expect(access_control.upload?(package, space)).to be_truthy
        end
      end

      context 'as a non-admin user' do
        let(:token) { { 'scope' => ['cloud_controller.write'] } }

        it 'disallows the user from uploading' do
          access_control = PackageModelAccess.new(access_context)
          expect(access_control.upload?(package, space)).to be_falsey
        end
      end
    end
  end
end

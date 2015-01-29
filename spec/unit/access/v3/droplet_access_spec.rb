require 'spec_helper'

module VCAP::CloudController
  describe DropletModelAccess, type: :access do
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

    describe '#create?' do
      let(:space) { Space.make }
      let(:droplet) { DropletModel.new(space_guid: space.guid) }

      context 'admin user' do
        let(:admin) { true }

        it 'allows the user to perform the action' do
          access_control = DropletModelAccess.new(access_context)
          expect(access_control.create?(package, space)).to be_truthy
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
            access_control = DropletModelAccess.new(access_context)
            expect(access_control.create?(package, space)).to be_truthy
          end
        end

        context 'when the user has insufficient scope' do
          let(:token) { { 'scope' => ['cloud_controller.read'] } }

          before do
            space.organization.add_user(user)
            space.add_developer(user)
          end

          it 'disallows the user from creating' do
            access_control = DropletModelAccess.new(access_context)
            expect(access_control.create?(package, space)).to be_falsey
          end
        end

        context 'when the user has insufficient permissions' do
          let(:token) { { 'scope' => ['cloud_controller.write'] } }

          it 'disallows the user from creating' do
            access_control = DropletModelAccess.new(access_context)
            expect(access_control.create?(package, space)).to be_falsey
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
            access_control = DropletModelAccess.new(access_context)
            expect(access_control.create?(package, space)).to be_falsey
          end
        end
      end
    end
  end
end

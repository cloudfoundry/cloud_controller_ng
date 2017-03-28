require 'spec_helper'
require 'actions/build_create'

module VCAP::CloudController
  RSpec.describe BuildCreate do
    subject(:action) { BuildCreate.new }

    let(:user) { User.make }
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user@example.com', user_guid: user.guid) }

    let(:space) { Space.make }
    let(:org) { space.organization }
    let(:app) { AppModel.make(space: space) }
    let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }
    let(:staging_message) { BuildCreateMessage.new(request) }
    let(:lifecycle) { BuildpackLifecycle.new(package, staging_message) }
    let(:request) do
      {
        package: {
          guid: package.guid,
        },
        lifecycle: {
          type: 'buildpack',
          data: lifecycle_data
        },
      }
    end
    let(:lifecycle_data) do
      {
        stack: Stack.default.name,
        buildpacks: ['http://example.com/repo.git']
      }
    end

    let(:stagers) { instance_double(Stagers) }
    let(:stager) { instance_double(Diego::Stager) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_app).and_return(stager)
      allow(stager).to receive(:stage)
    end

    describe '#create_and_stage' do
      # it 'creates an audit event' do
      #   expect(Repositories::DropletEventRepository).to receive(:record_create_by_staging).with(
      #     instance_of(BuildModel),
      #     user_audit_info,
      #     staging_message.audit_hash,
      #     app.name,
      #     space.guid,
      #     org.guid
      #   )
      #
      #   action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user_audit_info: user_audit_info)
      # end

      it 'creates a build' do
        build = nil
        expect {
          build = action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user_audit_info: user_audit_info)
        }.to change { BuildModel.count }.by(1)

        expect(build.state).to eq(BuildModel::STAGING_STATE)
        expect(build.package_guid).to eq(package.guid)
      end

      describe 'creating a stage request' do
        it 'initiates a staging request' do
          build = action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user_audit_info: user_audit_info)
          expect(stager).to have_received(:stage) do |staging_details|
            expect(staging_details.staging_guid).to eq(build.guid)
            expect(staging_details.package).to eq(package)
            expect(staging_details.lifecycle).to eq(lifecycle)
            expect(staging_details.isolation_segment).to be_nil
          end
        end

        describe 'isolation segments' do
          let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
          let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
          let(:isolation_segment_model_2) { VCAP::CloudController::IsolationSegmentModel.make }
          let(:shared_isolation_segment) {
            VCAP::CloudController::IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
          }

          context 'when the org has a default' do
            context 'and the default is the shared isolation segments' do
              before do
                assigner.assign(shared_isolation_segment, [org])
              end

              it 'does not set an isolation segment' do
                action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user_audit_info: user_audit_info)
                expect(stager).to have_received(:stage) do |staging_details|
                  expect(staging_details.isolation_segment).to be_nil
                end
              end
            end

            context 'and the default is not the shared isolation segment' do
              before do
                assigner.assign(isolation_segment_model, [org])
                org.update(default_isolation_segment_model: isolation_segment_model)
              end

              it 'sets the isolation segment' do
                action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user_audit_info: user_audit_info)
                expect(stager).to have_received(:stage) do |staging_details|
                  expect(staging_details.isolation_segment).to eq(isolation_segment_model.name)
                end
              end

              context 'and the space from that org has an isolation segment' do
                context 'and the isolation segment is the shared isolation segment' do
                  before do
                    assigner.assign(shared_isolation_segment, [org])
                    space.isolation_segment_model = shared_isolation_segment
                    space.save
                    space.reload
                  end

                  it 'does not set the isolation segment' do
                    action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user_audit_info: user_audit_info)
                    expect(stager).to have_received(:stage) do |staging_details|
                      expect(staging_details.isolation_segment).to be_nil
                    end
                  end
                end

                context 'and the isolation segment is not the shared or the default' do
                  before do
                    assigner.assign(isolation_segment_model_2, [org])
                    space.isolation_segment_model = isolation_segment_model_2
                    space.save
                  end

                  it 'sets the IS from the space' do
                    action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user_audit_info: user_audit_info)
                    expect(stager).to have_received(:stage) do |staging_details|
                      expect(staging_details.isolation_segment).to eq(isolation_segment_model_2.name)
                    end
                  end
                end
              end
            end
          end

          context 'when the org does not have a default' do
            context 'and the space from that org has an isolation segment' do
              context 'and the isolation segment is not the shared isolation segment' do
                before do
                  assigner.assign(isolation_segment_model, [org])
                  space.isolation_segment_model = isolation_segment_model
                  space.save
                end

                it 'sets the isolation segment' do
                  action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user_audit_info: user_audit_info)
                  expect(stager).to have_received(:stage) do |staging_details|
                    expect(staging_details.isolation_segment).to eq(isolation_segment_model.name)
                  end
                end
              end
            end
          end
        end
      end

      context 'when staging is unsuccessful' do
      end
    end
  end
end

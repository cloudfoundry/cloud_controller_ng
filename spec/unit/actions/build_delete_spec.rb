require 'spec_helper'
require 'actions/staging_cancel'
require 'actions/build_delete'

module VCAP::CloudController
  RSpec.describe BuildDelete do
    subject(:build_delete) { BuildDelete.new(cancel_action) }
    let(:cancel_action) { instance_double(StagingCancel, cancel: nil) }

    describe '#delete_for_app' do
      let!(:app) { AppModel.make }
      let!(:build1) { BuildModel.make(app: app, state: BuildModel::STAGED_STATE) }
      let!(:build2) { BuildModel.make(app: app, state: BuildModel::STAGING_STATE) }

      it 'deletes the builds' do
        expect do
          build_delete.delete_for_app(app.guid)
        end.to change(BuildModel, :count).by(-2)
        [build1, build2].each { |b| expect(b).not_to exist }
      end

      it 'cancels builds in STAGING_STATE' do
        build_delete.delete_for_app(app.guid)

        expect(cancel_action).to have_received(:cancel).with([build2])
      end

      it 'deletes associated labels' do
        label1 = BuildLabelModel.make(build: build1, key_name: 'test', value: 'bommel')
        label2 = BuildLabelModel.make(build: build2, key_name: 'test', value: 'bommel')

        expect do
          build_delete.delete_for_app(app.guid)
        end.to change(BuildLabelModel, :count).by(-2)
        [label1, label2].each { |l| expect(l).not_to exist }
      end

      it 'deletes associated annotations' do
        annotation1 = BuildAnnotationModel.make(build: build1, key_name: 'test', value: 'bommel')
        annotation2 = BuildAnnotationModel.make(build: build2, key_name: 'test', value: 'bommel')

        expect do
          build_delete.delete_for_app(app.guid)
        end.to change(BuildAnnotationModel, :count).by(-2)
        [annotation1, annotation2].each { |a| expect(a).not_to exist }
      end

      it 'deletes associated buildpack lifecycle data/buildpack' do
        lifecycle_data1 = BuildpackLifecycleDataModel.make(build: build1)
        lifecycle_data2 = BuildpackLifecycleDataModel.make(build: build2)
        lifecycle_buildpack1 = BuildpackLifecycleBuildpackModel.make(
          buildpack_lifecycle_data: lifecycle_data1, admin_buildpack_name: nil, buildpack_url: 'http://example.com/buildpack1'
        )
        lifecycle_buildpack2 = BuildpackLifecycleBuildpackModel.make(
          buildpack_lifecycle_data: lifecycle_data2, admin_buildpack_name: nil, buildpack_url: 'http://example.com/buildpack2'
        )

        expect do
          build_delete.delete_for_app(app.guid)
        end.to change(BuildpackLifecycleDataModel, :count).by(-2).and change(BuildpackLifecycleBuildpackModel, :count).by(-2)
        [lifecycle_data1, lifecycle_data2, lifecycle_buildpack1, lifecycle_buildpack2].each { |l| expect(l).not_to exist }
      end

      it 'deletes associated kpack lifecycle data' do
        lifecycle1 = KpackLifecycleDataModel.make(build: build1)
        lifecycle2 = KpackLifecycleDataModel.make(build: build2)

        expect do
          build_delete.delete_for_app(app.guid)
        end.to change(KpackLifecycleDataModel, :count).by(-2)
        [lifecycle1, lifecycle2].each { |l| expect(l).not_to exist }
      end
    end
  end
end

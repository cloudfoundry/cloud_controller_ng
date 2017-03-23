require 'spec_helper'
require 'presenters/v3/build_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe BuildPresenter do
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:build) do
      VCAP::CloudController::BuildModel.make
    end
    let(:package) do
      VCAP::CloudController::PackageModel.make(guid: 'abcdefabcdef12345', app: app)
    end

    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        state:                 VCAP::CloudController::DropletModel::STAGED_STATE,
        error_id:              'FAILED',
        error_description:     'things went all sorts of bad',
        process_types:         { 'web' => 'npm start', 'worker' => 'start worker' },
        environment_variables: { 'elastic' => 'runtime' },
        staging_memory_in_mb:  234,
        staging_disk_in_mb:    934,
        execution_metadata:    'black-box-string',
        package:               package,
        droplet_hash:          'droplet-sha1-checksum',
        sha256_checksum:       'droplet-sha256-checksum',
        build:                  build,
        app:                  app,
      )
    end

    describe '#to_hash' do
      let(:result) { BuildPresenter.new(build).to_hash }
      let(:buildpack) { 'the-happiest-buildpack' }
      let(:buildpack_receipt_buildpack) { 'the-happiest-buildpack' }

      context 'buildpack lifecycle' do
        before do
          droplet.lifecycle_data.buildpack        = buildpack
          droplet.lifecycle_data.stack            = 'the-happiest-stack'
          droplet.buildpack_receipt_buildpack     = buildpack_receipt_buildpack
          droplet.buildpack_receipt_detect_output = 'the-happiest-buildpack-detect-output'
          droplet.buildpack_receipt_stack_name    = 'the-happiest-stack'
          droplet.save
          build.droplet = droplet
        end

        it 'presents the build as a hash' do
          links = {
              self: { href: "#{link_prefix}/v3/builds/#{build.guid}" },
              app: { href: "#{link_prefix}/v3/apps/#{droplet.app_guid}" },
            }

          expect(result[:guid]).to eq(build.guid)
          expect(result[:state]).to eq('STAGING')
          expect(result[:error]).to eq(nil)

          expect(result[:lifecycle][:type]).to eq('buildpack')
          expect(result[:lifecycle][:data][:stack]).to eq('the-happiest-stack')
          expect(result[:lifecycle][:data][:buildpacks]).to eq(['the-happiest-buildpack'])

          expect(result[:created_at]).to be_a(Time)
          expect(result[:updated_at]).to be_a(Time)
          expect(result[:links]).to eq(links)
        end

        context 'when buildpack contains username and password' do
          let(:buildpack) { 'https://amelia:meow@neopets.com' }
          let(:buildpack_receipt_buildpack) { 'https://amelia:meow@neopets.com' }

          it 'obfuscates the username and password' do
            expect(result[:lifecycle][:data][:buildpacks]).to eq(['https://***:***@neopets.com'])
          end
        end

        context 'when there is no buildpack' do
          let(:buildpack) { nil }

          before do
            droplet.lifecycle_data.buildpack = buildpack
            droplet.save
          end

          it 'has an empty array of buildpacks' do
            expect(result[:lifecycle][:data][:buildpacks]).to eq([])
          end
        end
      end
    end
  end
end

require 'spec_helper'
require 'presenters/v3/build_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe BuildPresenter do
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:build) do
      VCAP::CloudController::BuildModel.make(state: VCAP::CloudController::BuildModel::STAGING_STATE)
    end
    let(:package) do
      VCAP::CloudController::PackageModel.make(guid: 'abcdefabcdef12345', app: app)
    end
    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        package: package,
        app: app,
      )
    end

    describe '#to_hash' do
      let(:result) { BuildPresenter.new(build).to_hash }
      let(:buildpack) { 'the-happiest-buildpack' }
      let(:buildpack_receipt_buildpack) { 'the-happiest-buildpack' }

      context 'buildpack lifecycle' do
        before do
          build.droplet = droplet
          droplet.lifecycle_data.buildpack = buildpack
          droplet.lifecycle_data.stack = 'the-happiest-stack'
          droplet.save
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
          expect(result[:lifecycle][:data][:buildpacks]).to eq(['the-happiest-buildpack'])
          expect(result[:lifecycle][:data][:stack]).to eq('the-happiest-stack')

          expect(result[:package][:guid]).to eq(package.guid)
          expect(result[:droplet]).to eq(nil)

          expect(result[:created_at]).to be_a(Time)
          expect(result[:updated_at]).to be_a(Time)
          expect(result[:links]).to eq(links)
        end

        context 'when buildpack contains username and password' do
          let(:buildpack) { 'https://amelia:meow@neopets.com' }

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

      context 'docker lifecycle' do
        let(:droplet) do
          VCAP::CloudController::DropletModel.make(
            :docker,
            package: package,
            app: app,
          )
        end

        before do
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

          expect(result[:lifecycle][:type]).to eq('docker')
          expect(result[:lifecycle][:data]).to eq({})

          expect(result[:package][:guid]).to eq(package.guid)
          expect(result[:droplet]).to eq(nil)

          expect(result[:created_at]).to be_a(Time)
          expect(result[:updated_at]).to be_a(Time)
          expect(result[:links]).to eq(links)
        end
      end
    end
  end
end

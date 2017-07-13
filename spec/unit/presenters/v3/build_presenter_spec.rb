require 'spec_helper'
require 'presenters/v3/build_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe BuildPresenter do
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:package) { VCAP::CloudController::PackageModel.make(app: app) }
    let!(:happy_buildpack) { VCAP::CloudController::Buildpack.make(name: 'the-happiest-buildpack') }
    let(:buildpacks) { [happy_buildpack.name, 'http://bob:secret@example.com/happy'] }
    let(:stack) { 'the-happiest-stack' }
    let(:build) do
      VCAP::CloudController::BuildModel.make(
        state:   VCAP::CloudController::BuildModel::STAGING_STATE,
        package: package,
        app:     app,
        created_by_user_guid: 'happy user guid',
        created_by_user_name: 'happier user name',
        created_by_user_email: 'this user emailed in'
      )
    end
    let!(:lifecycle_data) do
      VCAP::CloudController::BuildpackLifecycleDataModel.make(buildpacks: buildpacks, stack: stack, build: build)
    end

    describe '#to_hash' do
      let(:result) { BuildPresenter.new(build).to_hash }
      context 'buildpack lifecycle' do
        it 'presents the build as a hash' do
          links = {
            self: { href: "#{link_prefix}/v3/builds/#{build.guid}" },
            app:  { href: "#{link_prefix}/v3/apps/#{app.guid}" },
          }

          expect(result[:guid]).to eq(build.guid)
          expect(result[:state]).to eq('STAGING')
          expect(result[:error]).to eq(nil)

          expect(result[:lifecycle][:type]).to eq('buildpack')
          expect(result[:lifecycle][:data][:buildpacks]).to eq(['the-happiest-buildpack', 'http://***:***@example.com/happy'])
          expect(result[:lifecycle][:data][:stack]).to eq('the-happiest-stack')

          expect(result[:package][:guid]).to eq(package.guid)
          expect(result[:droplet]).to eq(nil)

          expect(result[:created_at]).to be_a(Time)
          expect(result[:updated_at]).to be_a(Time)
          expect(result[:links]).to eq(links)

          expect(result[:created_by]).to eq({
            guid: 'happy user guid',
            name: 'happier user name',
            email: 'this user emailed in',
          })
        end

        context 'when buildpack contains username and password' do
          let(:buildpacks) { ['https://amelia:meow@neopets.com'] }

          it 'obfuscates the username and password' do
            expect(result[:lifecycle][:data][:buildpacks]).to eq(['https://***:***@neopets.com'])
          end
        end

        context 'when there is no buildpack' do
          let(:buildpacks) { nil }

          it 'has an empty array of buildpacks' do
            expect(result[:lifecycle][:data][:buildpacks]).to eq([])
          end
        end
      end

      context 'docker lifecycle' do
        before do
          build.buildpack_lifecycle_data = nil
        end

        it 'presents the build as a hash' do
          links = {
            self: { href: "#{link_prefix}/v3/builds/#{build.guid}" },
            app:  { href: "#{link_prefix}/v3/apps/#{app.guid}" },
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

      context 'when the droplet has finished staging' do
        let(:droplet) do
          VCAP::CloudController::DropletModel.make(
            :buildpack,
            state:        VCAP::CloudController::DropletModel::STAGED_STATE,
            package_guid: package.guid,
            app:          app,
            build:        build
          )
        end

        before do
          build.droplet = droplet
          build.state = droplet.state
          build.save
        end

        it 'shows the droplet guid and state as STAGED' do
          expect(result[:state]).to eq('STAGED')
          expect(result[:error]).to eq(nil)
          expect(result[:droplet][:guid]).to eq(droplet.guid)
          expect(result[:droplet][:href]).to eq("#{link_prefix}/v3/droplets/#{droplet.guid}")
        end
      end

      context 'when the droplet stages with an error' do
        before do
          build.update(
            state:             VCAP::CloudController::BuildModel::FAILED_STATE,
            error_description: 'something bad',
            error_id:          'SomeError',
          )
        end

        it 'populates the error field and state as FAILED' do
          expect(result[:state]).to eq('FAILED')
          expect(result[:error]).to eq('SomeError - something bad')
        end
      end

      context 'when the package is deleted' do
        before do
          @package_guid = package.guid
          package.destroy
          build.reload
        end

        it 'still shows the package guid' do
          expect(result[:package][:guid]).to eq(@package_guid)
        end
      end
    end
  end
end

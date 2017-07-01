require 'spec_helper'
require 'presenters/v3/droplet_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe DropletPresenter do
    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        state:              VCAP::CloudController::DropletModel::STAGED_STATE,
        error_id:           'FAILED',
        error_description:  'things went all sorts of bad',
        process_types:      { 'web' => 'npm start', 'worker' => 'start worker' },
        execution_metadata: 'black-box-string',
        package_guid:       'abcdefabcdef12345',
        droplet_hash:       'droplet-sha1-checksum',
        sha256_checksum:    'droplet-sha256-checksum',
      )
    end

    describe '#to_hash' do
      let(:result) { DropletPresenter.new(droplet).to_hash }
      let(:buildpack) { 'the-happiest-buildpack' }
      let(:buildpack_receipt_buildpack) { 'the-happiest-buildpack' }

      context 'buildpack lifecycle' do
        before do
          droplet.lifecycle_data.buildpacks       = [buildpack]
          droplet.lifecycle_data.stack            = 'the-happiest-stack'
          droplet.buildpack_receipt_buildpack     = buildpack_receipt_buildpack
          droplet.buildpack_receipt_detect_output = 'the-happiest-buildpack-detect-output'
          droplet.save
        end

        it 'presents the droplet as a hash' do
          links = {
            self:                   { href: "#{link_prefix}/v3/droplets/#{droplet.guid}" },
            package:                { href: "#{link_prefix}/v3/packages/#{droplet.package_guid}" },
            app:                    { href: "#{link_prefix}/v3/apps/#{droplet.app_guid}" },
            assign_current_droplet: { href: "#{link_prefix}/v3/apps/#{droplet.app_guid}/relationships/current_droplet", method: 'PATCH' }
          }

          expect(result[:guid]).to eq(droplet.guid)
          expect(result[:state]).to eq('STAGED')
          expect(result[:error]).to eq('FAILED - things went all sorts of bad')

          expect(result[:lifecycle][:type]).to eq('buildpack')
          expect(result[:lifecycle][:data]).to eq({})

          expect(result[:checksum]).to eq(type: 'sha256', value: 'droplet-sha256-checksum')
          expect(result[:stack]).to eq('the-happiest-stack')
          expect(result[:buildpacks]).to eq([{ name: 'the-happiest-buildpack', detect_output: 'the-happiest-buildpack-detect-output' }])

          expect(result[:created_at]).to be_a(Time)
          expect(result[:updated_at]).to be_a(Time)
          expect(result[:links]).to eq(links)
        end

        it 'does not redacts the process_types and execution_metadata by default' do
          expect(result[:process_types]).to eq({ 'web' => 'npm start', 'worker' => 'start worker' })
          expect(result[:execution_metadata]).to eq('black-box-string')
        end

        context 'when buildpack contains username and password' do
          let(:buildpack) { 'https://amelia:meow@neopets.com' }
          let(:buildpack_receipt_buildpack) { 'https://amelia:meow@neopets.com' }

          it 'obfuscates the username and password' do
            expect(result[:buildpacks]).to eq([{ name: 'https://***:***@neopets.com', detect_output: 'the-happiest-buildpack-detect-output' }])
          end
        end

        context 'when show_secrets is false' do
          let(:result) { DropletPresenter.new(droplet, show_secrets: false).to_hash }

          it 'redacts the process_types and execution_metadata' do
            expect(result[:process_types]).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
            expect(result[:execution_metadata]).to eq('[PRIVATE DATA HIDDEN]')
          end
        end

        context 'when droplet has no checksum' do
          before { droplet.update(droplet_hash: nil, sha256_checksum: nil) }

          it 'sets checksum to nil' do
            expect(result[:checksum]).to eq(nil)
          end
        end

        context 'when the droplet does not have a sha256 checksum calculated' do
          before { droplet.update(sha256_checksum: nil) }

          it 'presents the sha1 checksum' do
            expect(result[:checksum]).to eq(type: 'sha1', value: 'droplet-sha1-checksum')
          end
        end

        describe 'links' do
          context 'when the buildpack is an admin buildpack' do
            let(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack, buildpack_receipt_buildpack_guid: 'some-guid') }

            it 'links to the buildpack' do
              expect(result[:links][:buildpack][:href]).to eq("#{link_prefix}/v2/buildpacks/some-guid")
            end
          end

          context 'when the buildpack is not an admin buildpack' do
            let(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack) }

            it 'links to nil' do
              expect(result[:links][:buildpack]).to be_nil
            end
          end

          context 'when there is no package guid' do
            let(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack, package_guid: nil) }

            it 'links to nil' do
              expect(result[:links][:package]).to be nil
            end
          end
        end
      end

      context 'docker lifecycle' do
        let(:droplet) do
          VCAP::CloudController::DropletModel.make(
            :docker,
            state: VCAP::CloudController::DropletModel::STAGED_STATE
          )
        end

        before do
          droplet.docker_receipt_image = 'test-image'
          droplet.save
        end

        it 'presents the docker image' do
          expect(result[:image]).to eq('test-image')
        end

        context 'when show_secrets is false' do
          let(:result) { DropletPresenter.new(droplet, show_secrets: false).to_hash }

          it 'redacts the process_types and execution_metadata' do
            expect(result[:process_types]).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
            expect(result[:execution_metadata]).to eq('[PRIVATE DATA HIDDEN]')
          end
        end
      end
    end
  end
end

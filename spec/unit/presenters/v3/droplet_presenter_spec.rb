require 'spec_helper'
require 'presenters/v3/droplet_presenter'

module VCAP::CloudController
  describe DropletPresenter do
    let(:droplet) do
      DropletModel.make(
        :buildpack,
        state:                 DropletModel::STAGED_STATE,
        error:                 'example error',
        process_types:         { 'web' => 'npm start', 'worker' => 'start worker' },
        environment_variables: { 'elastic' => 'runtime' },
        staging_memory_in_mb:          234,
        disk_limit:            934,
        execution_metadata:    'black-box-string',
        package_guid:          'abcdefabcdef12345'
      )
    end

    describe '#to_json' do
      let(:result) { DropletPresenter.new(droplet).to_hash }

      context 'buildpack lifecycle' do
        before do
          droplet.lifecycle_data.buildpack = 'the-happiest-buildpack'
          droplet.lifecycle_data.stack     = 'the-happiest-stack'
          droplet.buildpack_receipt_buildpack  = 'the-happiest-buildpack'
          droplet.buildpack_receipt_stack_name = 'the-happiest-stack'
          droplet.save
        end

        it 'presents the droplet as a hash' do
          expect(result[:guid]).to eq(droplet.guid)
          expect(result[:state]).to eq(droplet.state)
          expect(result[:error]).to eq(droplet.error)

          expect(result[:lifecycle][:type]).to eq('buildpack')
          expect(result[:lifecycle][:data]['stack']).to eq('the-happiest-stack')
          expect(result[:lifecycle][:data]['buildpack']).to eq('the-happiest-buildpack')
          expect(result[:environment_variables]).to eq(droplet.environment_variables)
          expect(result[:staging_memory_in_mb]).to eq(234)
          expect(result[:disk_limit]).to eq(934)

          expect(result[:created_at]).to be_a(Time)
          expect(result[:updated_at]).to be_a(Time)
          expect(result[:links]).to include(:self)
          expect(result[:links][:self][:href]).to eq("/v3/droplets/#{droplet.guid}")
          expect(result[:links]).to include(:package)
          expect(result[:links][:package][:href]).to eq("/v3/packages/#{droplet.package_guid}")
          expect(result[:links][:app][:href]).to eq("/v3/apps/#{droplet.app_guid}")
          expect(result[:links][:assign_current_droplet][:href]).to eq("/v3/apps/#{droplet.app_guid}/droplets/current")
          expect(result[:links][:assign_current_droplet][:method]).to eq('PUT')
        end

        describe 'result' do
          context 'when droplet is in a "complete" state' do
            before do
              droplet.state = DropletModel::COMPLETED_STATES.first
              droplet.save
            end

            it 'returns the result' do
              expect(result[:result][:process_types]).to eq({ 'web' => 'npm start', 'worker' => 'start worker' })
              expect(result[:result][:execution_metadata]).to eq('black-box-string')
            end
          end

          context 'when droplet is NOT in a "complete" state' do
            before do
              droplet.state = DropletModel::PENDING_STATE
              droplet.save
            end

            it 'returns nil for the result' do
              expect(result[:result]).to be_nil
            end
          end

          it 'has the correct result' do
            expect(result[:result][:hash]).to eq(type: 'sha1', value: nil)
            expect(result[:result][:buildpack]).to eq('the-happiest-buildpack')
            expect(result[:result][:stack]).to eq('the-happiest-stack')
          end

          describe 'links' do
            context 'when the buildpack is an admin buildpack' do
              let(:droplet) { DropletModel.make(:buildpack, buildpack_receipt_buildpack_guid: 'some-guid') }

              it 'links to the buildpack' do
                expect(result[:links][:buildpack][:href]).to eq('/v2/buildpacks/some-guid')
              end
            end

            context 'when the buildpack is not an admin buildpack' do
              let(:droplet) { DropletModel.make(:buildpack) }

              it 'links to nil' do
                expect(result[:links][:buildpack]).to be_nil
              end
            end

            context 'when there is no package guid' do
              let(:droplet) { DropletModel.make(:buildpack, package_guid: nil) }

              it 'links to nil' do
                expect(result[:links][:package]).to be nil
              end
            end
          end
        end
      end

      context 'docker lifecycle' do
        let(:droplet) do
          DropletModel.make(
            :docker,
            state: DropletModel::STAGED_STATE
          )
        end

        before do
          droplet.docker_receipt_image = 'test-image'
          droplet.save
        end

        it 'has the correct result' do
          expect(result[:result][:image]).to eq('test-image')
        end
      end
    end
  end
end

require 'spec_helper'
require 'actions/space_diff_manifest'

module VCAP::CloudController
  RSpec.describe SpaceDiffManifest do
    describe 'generate_diff' do
      let(:default_manifest) {
        {
          'applications' => [
            {
              'name' => app1_model.name,
              'stack' => process1.stack.name,
              'routes' => [
                {
                  'route' => "a_host.#{shared_domain.name}"
                }
              ],
              'processes' => [
                {
                  'type' => process1.type,
                  'instances' => process1.instances,
                  'memory' => '1024M',
                  'disk_quota' => '1024M',
                  'health-check-type' =>  process1.health_check_type
                }
              ]
            },
          ]
        }
      }

      let(:app_manifests) { default_manifest['applications'] }
      let(:space) { Space.make }
      let(:app1_model) { AppModel.make(name: 'app-1', space: space) }
      let!(:process1) { ProcessModel.make(app: app1_model) }
      let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
      let(:route) { VCAP::CloudController::Route.make(domain: shared_domain, space: space, host: 'a_host') }
      let!(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app1_model, process_type: process1.type, route: route) }

      subject { SpaceDiffManifest.generate_diff(app_manifests, space) }

      context 'when a top-level field is omitted' do
        before do
          default_manifest['applications'][0].delete 'stack'
        end

        it 'returns an empty diff' do
          expect(subject).to eq([])
        end
      end

      context 'when there is an unrecognized top-level field' do
        before do
          default_manifest['applications'][0]['foo'] = 'bar'
        end

        it 'returns an empty diff' do
          expect(subject).to eq([])
        end
      end

      context 'when there are changes in the manifest' do
        before do
          default_manifest['applications'][0]['random_route'] = true
          default_manifest['applications'][0]['stack'] = 'big brother'
        end

        it 'returns the correct diff' do
          expect(subject).to match_array([
            { 'op' => 'add', 'path' => '/applications/0/random_route', 'value' => true },
            { 'op' => 'replace', 'path' => '/applications/0/stack', 'was' => process1.stack.name, 'value' => 'big brother' },
          ])
        end
      end

      context 'metadata is added' do
        before do
          default_manifest['applications'][0]['metadata'] = {
            'labels' => { 'foo' => 'bar' },
            'annotations' => { 'baz' => 'qux' }
          }
        end

        it 'returns the correct diff' do
          expect(subject).to eq([
            { 'op' => 'add', 'path' => '/applications/0/metadata', 'value' => {
              'labels' => { 'foo' => 'bar' },
              'annotations' => { 'baz' => 'qux' },
            } },
          ])
        end
      end

      context 'services are added' do
        before do
          default_manifest['applications'][0]['services'] = [
            'service-without-name-label',
            {
              'name' => 'foo',
              'parameters' => { 'baz' => 'qux' }
            }
          ]
        end

        it 'returns the correct diff' do
          expect(subject).to eq([
            { 'op' => 'add', 'path' => '/applications/0/services', 'value' => [
              'service-without-name-label',
              {
                'name' => 'foo',
                'parameters' => { 'baz' => 'qux' }
              }
            ] },
          ])
        end
      end

      context 'when there is a change inside of a nested hash' do
        before do
          default_manifest['applications'][0]['processes'][0].delete('memory')
        end

        it 'returns the correct diff' do
          expect(subject).to eq([
            { 'op' => 'remove', 'path' => '/applications/0/processes/0/memory', 'was' => '1024M' },
          ])
        end
      end

      context 'when there is a change inside of a nested array' do
        before do
          default_manifest['applications'][0]['sidecars'] = [
            { 'name' => 'sidecar1', 'command' => 'bundle exec rake lol', 'process_types' => ['web', 'worker'] }
          ]
        end

        it 'returns the correct diff' do
          expect(subject).to eq([
            {
              'op' => 'add',
              'path' => '/applications/0/sidecars',
              'value' => [
                { 'name' => 'sidecar1', 'command' => 'bundle exec rake lol', 'process_types' => ['web', 'worker'] }
              ]
            },
          ])
        end
      end

      context 'when changing sidecar properties on an existing sidecar' do
        let!(:sidecar) { SidecarModel.make(app: app1_model, memory: 500, name: 'sidecar1') }
        let!(:sidecar_process_type_model) { SidecarProcessTypeModel.make(type: 'web', sidecar: sidecar) }

        before do
          default_manifest['applications'][0]['sidecars'] = [
            {
              'name' => 'sidecar1',
              'command' => 'bundle exec rake lol',
              'process_types' => ['web'],
              'memory' => '500M',
            }
          ]
        end

        it 'returns the correct diff' do
          expect(subject).to eq([
            {
              'op' => 'replace',
              'path' => '/applications/0/sidecars/0/command',
              'value' => 'bundle exec rake lol',
              'was' => 'bundle exec rackup',
            },
          ])
        end
      end

      context 'when there is an unrecognized field in a nested hash' do
        before do
          default_manifest['applications'][0]['processes'][0]['foo'] = 'bar'
          default_manifest['applications'][0]['services'] = [
            {
              'foo' => 'bar'
            }
          ]

          default_manifest['applications'][0]['metadata'] = {
           'foo' => 'bar'
          }
          default_manifest['applications'][0]['sidecars'] = [
            {
              'foo' => 'bar'
            }
          ]
        end

        it 'returns an empty diff' do
          expect(subject).to eq([])
        end
      end

      context 'when there is a new app' do
        let(:app_manifests) do
          [
            {
              'name' => 'new-app',
            },
            {
              'name' => 'newer-app',
            }
          ]
        end

        it 'returns the correct diff' do
          expect(subject).to eq([
            { 'op' => 'add', 'path' => '/applications/0/name', 'value' => 'new-app' },
            { 'op' => 'add', 'path' => '/applications/1/name', 'value' => 'newer-app' },
          ])
        end
      end

      context 'when performing byte unit conversions' do
        context 'when the field is equivalent' do
          before do
            default_manifest['applications'][0]['processes'][0]['memory'] = '1G'
            default_manifest['applications'][0]['processes'][0]['disk_quota'] = '1G'
          end
          it 'returns an empty diff' do
            expect(subject).to eq([])
          end
        end

        context 'when the field is not equivalent' do
          before do
            default_manifest['applications'][0]['processes'][0]['memory'] = '2G'
            default_manifest['applications'][0]['processes'][0]['disk_quota'] = '4G'
          end
          it 'returns the diff formatted as megabytes' do
            expect(subject).to eq([
              { 'op' => 'replace', 'path' => '/applications/0/processes/0/memory', 'value' => '2048M', 'was' => '1024M' },
              { 'op' => 'replace', 'path' => '/applications/0/processes/0/disk_quota', 'value' => '4096M', 'was' => '1024M' },
            ])
          end
        end

        context 'when updating sidecar configurations' do
          let(:default_manifest) {
            {
              'applications' => [
                {
                  'name' => app1_model.name,
                  'stack' => process1.stack.name,
                  'routes' => [
                    {
                      'route' => "a_host.#{shared_domain.name}"
                    }
                  ],
                  'sidecars' => [
                    {
                      'name' => sidecar_model.name,
                      'process_types' => [sidecar_process_type_model.type],
                      'command' => sidecar_model.command,
                      'memory' => '2G',
                    }
                  ]
                },
              ]
            }
          }
          let!(:sidecar_process_model) { ProcessModel.make(app: app1_model) }
          let!(:sidecar_model) { SidecarModel.make(app: app1_model, memory: 2048) }
          let!(:sidecar_process_type_model) { SidecarProcessTypeModel.make(type: sidecar_process_model.type, sidecar: sidecar_model) }

          it 'returns an empty diff if the field is equivalent' do
            expect(subject).to eq([])
          end
        end

        context 'when updating app-level configurations' do
          before do
            default_manifest['applications'][0]['memory'] = '1G'
            default_manifest['applications'][0]['disk_quota'] = '1G'
          end

          it 'returns an empty diff if the field is equivalent' do
            expect(subject).to eq([])
          end
        end
      end

      context 'when the user passes in a v2 manifest' do
        let(:default_manifest) {
          {
            'applications' => [
              {
                'name' => app1_model.name,
                'memory' => '256M'
              }
            ]
          }
        }

        it 'returns the correct diff' do
          expect(subject).to match_array([
            { 'op' => 'replace', 'path' => '/applications/0/memory', 'was' => "#{process1.memory}M", 'value' => '256M' },
          ])
        end
      end
    end
  end
end

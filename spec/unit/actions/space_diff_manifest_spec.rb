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
                  'log-rate-limit-per-second' => '1M',
                  'health-check-type' =>  process1.health_check_type,
                  'readiness-health-check-type' =>  process1.readiness_health_check_type
                },
                {
                  'type' => process2.type,
                  'instances' => process2.instances,
                  'memory' => '1024M',
                  'disk_quota' => '1024M',
                  'log-rate-limit-per-second' => '1M',
                  'health-check-type' =>  process2.health_check_type,
                  'readiness-health-check-type' =>  process2.readiness_health_check_type
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
      let!(:process2) { ProcessModel.make(app: app1_model, type: 'worker') }
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
          default_manifest['applications'][0]['random-route'] = true
          default_manifest['applications'][0]['stack'] = 'big brother'
        end

        it 'returns the correct diff' do
          expect(subject).to match_array([
            { 'op' => 'add', 'path' => '/applications/0/random-route', 'value' => true },
            { 'op' => 'replace', 'path' => '/applications/0/stack', 'was' => process1.stack.name, 'value' => 'big brother' },
          ])
        end
      end

      context 'processes' do
        context 'when processes are added' do
          before do
            default_manifest['applications'][0]['processes'][0]['memory'] = '2048M'
          end

          it 'returns the correct diff' do
            expect(subject).to contain_exactly(
              { 'op' => 'replace', 'path' => '/applications/0/processes/0/memory', 'was' => "#{process1.memory}M", 'value' => '2048M' },
            )
          end
        end

        context 'when processes do not change' do
          let!(:process1) { ProcessModel.make(app: app1_model, memory: 256) }
          before do
            default_manifest['applications'][0]['processes'][0]['memory'] = '256M'
          end

          it 'returns an empty diff' do
            expect(subject).to eq([])
          end
        end

        context 'when a process is not represented in the manifest' do
          before do
            default_manifest['applications'][0]['processes'].delete_at(1)
          end

          it 'returns an empty diff' do
            expect(subject).to eq([])
          end
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

      context 'when there is a removal inside the processes hash' do
        before do
          default_manifest['applications'][0]['processes'][0].delete('memory')
        end

        it 'does not report a change' do
          expect(subject).to eq([])
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
            default_manifest['applications'][0]['processes'][0]['log-rate-limit-per-second'] = '1024K'
          end
          it 'returns an empty diff' do
            expect(subject).to eq([])
          end
        end

        context 'when the field is not equivalent' do
          before do
            default_manifest['applications'][0]['processes'][0]['memory'] = '2G'
            default_manifest['applications'][0]['processes'][0]['disk_quota'] = '4G'
            default_manifest['applications'][0]['processes'][0]['health-check-type'] = 'process'
            default_manifest['applications'][0]['processes'][0]['health-check-interval'] = 10
            default_manifest['applications'][0]['processes'][0]['readiness-health-check-type'] = 'port'
            default_manifest['applications'][0]['processes'][0]['readiness-health-check-interval'] = 20
            default_manifest['applications'][0]['processes'][0]['log-rate-limit-per-second'] = '2G'
          end
          it 'returns the diff formatted' do
            expect(subject).to eq([
              { 'op' => 'add', 'path' => '/applications/0/processes/0/health-check-interval', 'value' => 10 },
              { 'op' => 'add', 'path' => '/applications/0/processes/0/readiness-health-check-interval', 'value' => 20 },
              { 'op' => 'replace', 'path' => '/applications/0/processes/0/memory', 'value' => '2048M', 'was' => '1024M' },
              { 'op' => 'replace', 'path' => '/applications/0/processes/0/disk_quota', 'value' => '4096M', 'was' => '1024M' },
              { 'op' => 'replace', 'path' => '/applications/0/processes/0/log-rate-limit-per-second', 'value' => '2G', 'was' => '1M' },
              { 'op' => 'replace', 'path' => '/applications/0/processes/0/health-check-type', 'value' => 'process', 'was' => 'port' },
              { 'op' => 'replace', 'path' => '/applications/0/processes/0/readiness-health-check-type', 'value' => 'port', 'was' => 'process' },
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
          context 'when nothing has changed' do
            before do
              default_manifest['applications'][0]['log-rate-limit-per-second'] = '1024K'
            end

            it 'returns an empty diff if the field is equivalent' do
              expect(subject).to eq([])
            end
          end

          context 'when trying to change memory and disk quota' do
            before do
              default_manifest['applications'][0]['memory'] = '99G'
              default_manifest['applications'][0]['disk_quota'] = '99G'
            end

            it 'returns an empty diff because for some reason we ignore these fields at the app level' do
              expect(subject).to eq([])
            end
          end

          context 'when things have changed' do
            before do
              default_manifest['applications'][0]['health-check-type'] = 'process'
              default_manifest['applications'][0]['instances'] = 9
              default_manifest['applications'][0]['log-rate-limit-per-second'] = '1G'
            end

            it 'displays in the diff' do
              expect(subject).to eq([
                {
                  'op' => 'replace',
                  'path' => '/applications/0/health-check-type',
                  'was' => 'port',
                  'value' => 'process'
                },
                {
                  'op' => 'replace',
                  'path' => '/applications/0/instances',
                  'was' => 1,
                  'value' => 9
                },
                {
                  'op' => 'replace',
                  'path' => '/applications/0/log-rate-limit-per-second',
                  'was' => '1M',
                  'value' => '1G'
                }
              ])
            end
          end
        end
      end

      describe 'log-rate-limit-per-second' do
        it 'can handle -1 as a string for unlimited' do
          default_manifest['applications'][0]['log-rate-limit-per-second'] = '-1'

          expect(subject).to include(
            {
              'op' => 'replace',
              'path' => '/applications/0/log-rate-limit-per-second',
              'value' => '-1',
              'was' => '1M'
            }
          )
        end

        it 'can handle -1 as a number for unlimited' do
          default_manifest['applications'][0]['log-rate-limit-per-second'] = -1

          expect(subject).to include(
            {
              'op' => 'replace',
              'path' => '/applications/0/log-rate-limit-per-second',
              'value' => '-1',
              'was' => '1M'
            }
          )
        end

        it 'can handle 0 as a string without units' do
          default_manifest['applications'][0]['log-rate-limit-per-second'] = '0'

          expect(subject).to include(
            {
              'op' => 'replace',
              'path' => '/applications/0/log-rate-limit-per-second',
              'value' => '0',
              'was' => '1M'
            }
          )
        end

        it 'can handle 0 as a number without units' do
          default_manifest['applications'][0]['log-rate-limit-per-second'] = 0

          expect(subject).to include(
            {
              'op' => 'replace',
              'path' => '/applications/0/log-rate-limit-per-second',
              'value' => '0',
              'was' => '1M'
            }
          )
        end
      end

      context 'when the user passes in a v2 manifest' do
        let(:default_manifest) {
          {
            'applications' => [
              {
                'name' => app1_model.name,
                'instances' => 5
              }
            ]
          }
        }

        it 'returns the correct diff' do
          expect(subject).to match_array([
            { 'op' => 'replace', 'path' => '/applications/0/instances', 'was' => process1.instances, 'value' => 5 },
          ])
        end
      end

      context 'when the user passes in protocols manifest' do
        context 'when it is same protocol' do
          let(:default_manifest) {
            {
              'applications' => [
                {
                  'name' => app1_model.name,
                  'routes' => [
                    {
                      'route' => "a_host.#{shared_domain.name}",
                      'protocol' => 'http1'
                    }
                  ]
                }
              ]
            }
          }

          it 'returns an empty diff if the field is equivalent' do
            expect(subject).to match_array([])
          end
        end

        context 'when it is different protocol' do
          let(:default_manifest) {
            {
              'applications' => [
                {
                  'name' => app1_model.name,
                  'routes' => [
                    {
                      'route' => "a_host.#{shared_domain.name}",
                      'protocol' => 'http2'
                    }
                  ]
                }
              ]
            }
          }

          it 'returns an empty diff if the field is equivalent' do
            expect(subject).to match_array([
              { 'op' => 'replace', 'path' => '/applications/0/routes/0/protocol', 'was' => 'http1', 'value' => 'http2' },
            ])
          end
        end
      end
    end
  end
end

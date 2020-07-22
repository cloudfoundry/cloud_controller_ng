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

      context 'when there is an unrecognized field in a nested hash' do
        before do
          default_manifest['applications'][0]['processes'][0]['foo'] = 'bar'
          default_manifest['applications'][0]['services'] = [
            {
              'foo' => 'bar'
            }
          ]

          default_manifest['applications'][0]['metadata'] = [
            {
              'foo' => 'bar'
            }
          ]
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

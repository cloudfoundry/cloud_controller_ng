require 'spec_helper'
require 'cloud_controller/diego/protocol/app_volume_mounts'

module VCAP::CloudController
  module Diego
    class Protocol
      RSpec.describe AppVolumeMounts do
        subject(:mounts) { AppVolumeMounts.new(app) }

        let(:app) { App.make }
        let(:service_instance) { ServiceInstance.make(space: app.space) }
        let(:service_instance2) { ServiceInstance.make(space: app.space) }

        let(:multiple_volume_mounts) do
          [
            {
                container_dir: '/data/images',
                mode: 'r',
                device_type: 'shared',
                device: {
                    driver: 'cephfs',
                    volume_id: 'abc',
                    mount_config: {
                        key: 'value'
                    }
                }
            },
            {
                container_dir: '/data/scratch',
                mode: 'rw',
                device_type: 'shared',
                device: {
                    driver: 'local',
                    volume_id: 'def',
                    mount_config: {}
                }
            }
          ]
        end

        let(:single_volume_mount) do
          [
            {
                container_dir: '/data/videos',
                mode: 'rw',
                device_type: 'shared',
                device: {
                    driver: 'local',
                    volume_id: 'ghi',
                    mount_config: {
                        foo: 'bar'
                    }
                }
            }
          ]
        end

        it "is a flat array of all volume mounts in the app's service bindings" do
          ServiceBinding.make(app: app, service_instance: service_instance, volume_mounts: multiple_volume_mounts)
          ServiceBinding.make(app: app, service_instance: service_instance2, volume_mounts: single_volume_mount)

          expect(mounts.as_json).to match_array([
            {
                'container_dir' => '/data/images',
                'mode' => 'r',
                'device_type' => 'shared',
                'device' => {
                    'driver' => 'cephfs',
                    'volume_id' => 'abc',
                    'mount_config' => {
                        'key' => 'value',
                    },
                },
            },
            {
                'container_dir' => '/data/scratch',
                'mode' => 'rw',
                'device_type' => 'shared',
                'device' => {
                    'driver' => 'local',
                    'volume_id' => 'def',
                    'mount_config' => {},
                },
            },
            {

                'container_dir' => '/data/videos',
                'mode' => 'rw',

                'device_type' => 'shared',
                'device' => {
                  'driver' => 'local',
                  'volume_id' => 'ghi',
                  'mount_config' => {
                      'foo' => 'bar',
                  },
                },
            }
          ])
        end

        it 'does not include empty entries for service bindings with no volume mounts' do
          ServiceBinding.make(app: app, service_instance: service_instance, volume_mounts: single_volume_mount)
          ServiceBinding.make(app: app, service_instance: service_instance2)

          expect(mounts.as_json).to match_array([
            {
                'container_dir' => '/data/videos',
                'mode' => 'rw',

                'device_type' => 'shared',
                'device' => {
                    'driver' => 'local',
                    'volume_id' => 'ghi',
                    'mount_config' => {
                        'foo' => 'bar',
                    },
                },
            }
          ])
        end
      end
    end
  end
end

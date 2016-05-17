require 'spec_helper'
require 'cloud_controller/diego/protocol/app_volume_mounts'

module VCAP::CloudController
  module Diego
    class Protocol
      describe AppVolumeMounts do
        subject(:mounts) { AppVolumeMounts.new(app) }

        let(:app) { App.make }
        let(:service_instance) { ServiceInstance.make(space: app.space) }
        let(:service_instance2) { ServiceInstance.make(space: app.space) }

        let(:multiple_volume_mounts) do
          [
            {
              container_path: '/data/images',
              mode:           'r',
              private:        {
                driver:   'cephfs',
                group_id: 'abc',
                config:   'something',
              },
            },
            {
              container_path: '/data/scratch',
              mode:           'rw',
              private:        {
                driver:   'localscratch',
                group_id: '123',
                config:   'something else',
                tags:     { "iops": ['10k'] },
                size_mb:  512,
              }
            }
          ]
        end

        let(:single_volume_mount) do
          [
            {
              container_path: '/data/videos',
              mode:           'wr',
              private:        {
                driver:   'cephfs',
                group_id: '123',
                config:   'something other'
              }
            }
          ]
        end

        it "is a flat array of all volume mounts in the app's service bindings" do
          ServiceBinding.make(app: app, service_instance: service_instance, volume_mounts: multiple_volume_mounts)
          ServiceBinding.make(app: app, service_instance: service_instance2, volume_mounts: single_volume_mount)

          expect(mounts.as_json).to match_array([
            {
              'driver'         => 'cephfs',
              'volume_id'      => 'abc',
              'container_path' => '/data/images',
              'mode'           => 0,
              'config'         => Base64.encode64('something')
            },
            {
              'driver'         => 'localscratch',
              'volume_id'      => '123',
              'container_path' => '/data/scratch',
              'mode'           => 1,
              'config'         => Base64.encode64('something else')
            },
            {
              'driver'         => 'cephfs',
              'volume_id'      => '123',
              'container_path' => '/data/videos',
              'mode'           => 1,
              'config'         => Base64.encode64('something other')
            }
          ])
        end

        it 'does not include empty entries for service bindings with no volume mounts' do
          ServiceBinding.make(app: app, service_instance: service_instance, volume_mounts: single_volume_mount)
          ServiceBinding.make(app: app, service_instance: service_instance2)

          expect(mounts.as_json).to match_array([
            {
              'driver'         => 'cephfs',
              'volume_id'      => '123',
              'container_path' => '/data/videos',
              'mode'           => 1,
              'config'         => Base64.encode64('something other')
            }
          ])
        end
      end
    end
  end
end

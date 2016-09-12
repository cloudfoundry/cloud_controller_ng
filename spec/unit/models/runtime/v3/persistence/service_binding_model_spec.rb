require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceBindingModel do
    let(:credentials) { { 'secret' => 'password' }.to_json }
    let(:volume_mounts) { [].to_json }
    let(:last_row) { ServiceBindingModel.dataset.naked.order_by(:id).last }
    let!(:service_binding) { ServiceBindingModel.make(credentials: credentials, volume_mounts: volume_mounts) }

    context 'credentials' do
      it 'encrypts the credentials' do
        expect(last_row[:credentials]).not_to eq MultiJson.dump(credentials).to_s
      end
    end

    context 'volume_mounts' do
      it 'encrypts the volume_mounts' do
        expect(last_row[:volume_mounts]).not_to eq MultiJson.dump(volume_mounts).to_s
      end
    end

    context 'validations' do
      let(:service_instance) { ManagedServiceInstance.make }
      let(:app_model) { AppModel.make(space_guid: service_instance.space.guid) }

      context 'when the service instance is already bound to the app' do
        before do
          ServiceBindingModel.make(service_instance: service_instance, app: app_model)
        end

        it 'is not valid' do
          expect {
            ServiceBindingModel.make(service_instance: service_instance, app: app_model)
          }.to raise_error(Sequel::ValidationFailed, /service_instance and app unique/)
        end
      end

      context 'when the service instance and app are in different spaces' do
        let(:app_model) { AppModel.make }

        it 'is not valid' do
          expect { ServiceBindingModel.make(service_instance: service_instance, app: app_model)
          }.to raise_error(Sequel::ValidationFailed, /service_instance space_mismatch/)
        end
      end

      it 'must have a service instance' do
        expect { ServiceBindingModel.make(service_instance: nil, app: app_model)
        }.to raise_error(Sequel::ValidationFailed, /service_instance presence/)
      end

      it 'must have an app' do
        expect { ServiceBindingModel.make(service_instance: service_instance, app: nil)
        }.to raise_error(Sequel::ValidationFailed, /app presence/)
      end

      it 'must have a type' do
        expect { ServiceBindingModel.make(type: nil, service_instance: service_instance, app: app_model)
        }.to raise_error(Sequel::ValidationFailed, /type presence/)
      end

      it 'passes validation when mount config is null' do
        good_mount = '[{"driver":"foo", "container_dir":"/", "mode":"rw", "device_type":"shared", "device":{"volume_id":"a", "mount_config":null}}]'

        binding = ServiceBindingModel.make
        binding.volume_mounts = good_mount
        expect { binding.save }.not_to raise_error
      end

      it 'passes validation when mount config is missing' do
        good_mount = '[{"driver":"foo", "container_dir":"/", "mode":"rw", "device_type":"shared", "device":{"volume_id":"a"}}]'

        binding = ServiceBindingModel.make
        binding.volume_mounts = good_mount
        expect { binding.save }.not_to raise_error
      end

      it 'validates max length of volume_mounts' do
        too_long = 'a' * 65_535
        bad_mount = '[{"driver":"foo", "container_dir":"/", "mode":"rw", "device_type":"shared", "device":{"volume_id":"a", "mount_config":{"a":"' +
            too_long + '"}}}]'

        binding = ServiceBindingModel.make
        binding.volume_mounts = bad_mount

        expect { binding.save }.to raise_error(Sequel::ValidationFailed, /volume_mounts max_length/)
      end

      def verify_mount_option(bad_mount, exception, content)
        binding = ServiceBindingModel.make
        binding.volume_mounts = bad_mount
        expect { binding.save }.to raise_error(exception, content)
      end

      it 'validates that volume_mounts have a device type' do
        bad_mount = '[{"driver":"foo", "container_dir":"/", "mode":"rw", "device":{"volume_id":"a", "mount_config":{}}}]'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /device_type/)
      end
      it 'validates that volume_mounts have a device' do
        bad_mount = '[{"driver":"foo", "container_dir":"/", "device_type":"shared", "mode":"rw"}]'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /'device'/)
      end
      it 'validates that volume_mounts have a mode' do
        bad_mount = '[{"driver":"foo", "container_dir":"/", "device_type":"shared", "device":{"volume_id":"a", "mount_config":{}}}]'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /mode/)
      end
      it 'validates that volume_mounts have a container_dir' do
        bad_mount = '[{"driver":"foo", "device_type":"shared", "mode":"rw", "device":{"volume_id":"a", "mount_config":{}}}]'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /container_dir/)
      end
      it 'validates that volume_mounts have a driver' do
        bad_mount = '[{"container_dir":"/", "device_type":"shared", "mode":"rw", "device":{"volume_id":"a", "mount_config":{}}}]'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /driver/)
      end
      it 'validates that volume_mounts is an array' do
        bad_mount = '{"driver":"foo", "container_dir":"/", "device_type":"shared", "mode":"rw", "device":{"volume_id":"a", "mount_config":{}}}'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /must be an Array/)
      end
      it 'validates that volume_mounts elements are json objects' do
        bad_mount = '[{"driver":"foo", "container_dir":"/", "device_type":"shared", "mode":"rw", "device":{"volume_id":"a", "mount_config":{}}}, "extra junk"]'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /must be an object/)
      end
      it 'validates that volume_mounts.device elements are json objects' do
        bad_mount = '[{"driver":"foo", "container_dir":"/", "device_type":"shared", "mode":"rw", "device":"junk"}]'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /must be an object/)
      end
      it 'validates that volume_mounts.device.mount_config elements are json objects' do
        bad_mount = '[{"driver":"foo", "container_dir":"/", "device_type":"shared", "mode":"rw", "device":{"volume_id":"a", "mount_config":["junk"]}}]'

        verify_mount_option(bad_mount, ServiceBindingModel::InvalidVolumeMount, /must be an object/)
      end

      describe 'changing the binding after creation' do
        let(:service_binding) { ServiceBindingModel.make }
        let(:app_model) { service_binding.app }
        let(:service_instance) { service_binding.service_instance }

        describe 'the associated app' do
          it 'allows changing to the same app' do
            service_binding.app = app_model
            expect { service_binding.save }.not_to raise_error
          end

          it 'does not allow changing app after it has been set' do
            service_binding.app = AppModel.make(space: service_binding.app.space)
            expect { service_binding.save }.to raise_error Sequel::ValidationFailed, /app/
          end
        end

        describe 'the associated service instance' do
          it 'allows changing to the same service instance' do
            service_binding.service_instance = service_binding.service_instance
            expect { service_binding.save }.not_to raise_error
          end

          it 'does not allow changing service_instance after it has been set' do
            service_binding.service_instance = ServiceInstance.make(space: service_binding.app.space)
            expect { service_binding.save }.to raise_error Sequel::ValidationFailed, /service_instance/
          end
        end
      end
    end

    describe '#new' do
      it 'has a guid when constructed' do
        binding = described_class.new
        expect(binding.guid).to be
      end
    end

    describe 'logging'
    describe '#in_suspended_org?'
  end
end

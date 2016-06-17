require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceBindingModel do
    let(:credentials) { { 'secret' => 'password' }.to_json }
    let(:volume_mounts) { [{ 'array' => 'hashes' }].to_json }
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

      it 'validates max length of volume_mounts' do
        too_long = 'a' * (65_535 + 1)

        binding = ServiceBindingModel.make
        binding.volume_mounts = too_long

        expect { binding.save }.to raise_error(Sequel::ValidationFailed, /volume_mounts max_length/)
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

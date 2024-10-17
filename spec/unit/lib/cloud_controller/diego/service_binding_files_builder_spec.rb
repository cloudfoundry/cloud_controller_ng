require 'spec_helper'
require 'cloud_controller/diego/service_binding_files_builder'

module VCAP::CloudController::Diego
  RSpec.shared_examples 'mapping of type and provider' do |label|
    it 'sets type and provider to the service label' do
      expect(service_binding_files.find { |f| f.path == "#{directory}/type" }).to have_attributes(content: label || 'service-name')
      expect(service_binding_files.find { |f| f.path == "#{directory}/provider" }).to have_attributes(content: label || 'service-name')
      expect(service_binding_files.find { |f| f.path == "#{directory}/label" }).to have_attributes(content: label || 'service-name')
    end
  end

  RSpec.shared_examples 'mapping of binding metadata' do |name|
    it 'maps service binding metadata attributes to files' do
      expect(service_binding_files.find { |f| f.path == "#{directory}/binding-guid" }).to have_attributes(content: binding.guid)
      expect(service_binding_files.find { |f| f.path == "#{directory}/name" }).to have_attributes(content: name || 'binding-name')
      expect(service_binding_files.find { |f| f.path == "#{directory}/binding-name" }).to have_attributes(content: 'binding-name') if name.nil?
    end
  end

  RSpec.shared_examples 'mapping of instance metadata' do |instance_name|
    it 'maps service instance metadata attributes to files' do
      expect(service_binding_files.find { |f| f.path == "#{directory}/instance-guid" }).to have_attributes(content: instance.guid)
      expect(service_binding_files.find { |f| f.path == "#{directory}/instance-name" }).to have_attributes(content: instance_name || 'instance-name')
    end
  end

  RSpec.shared_examples 'mapping of plan metadata' do
    it 'maps service plan metadata attributes to files' do
      expect(service_binding_files.find { |f| f.path == "#{directory}/plan" }).to have_attributes(content: 'plan-name')
    end
  end

  RSpec.shared_examples 'mapping of tags' do |tags|
    it 'maps (service tags merged with) instance tags to a file' do
      expect(service_binding_files.find do |f|
        f.path == "#{directory}/tags"
      end).to have_attributes(content: tags || '["a-service-tag","another-service-tag","an-instance-tag","another-instance-tag"]')
    end
  end

  RSpec.shared_examples 'mapping of credentials' do |credential_files|
    it 'maps service binding credentials to individual files' do
      expected_credential_files = credential_files || {
        string: 'a string',
        number: '42',
        boolean: 'true',
        array: '["one","two","three"]',
        hash: '{"key":"value"}'
      }
      expected_credential_files.each do |name, content|
        expect(service_binding_files.find { |f| f.path == "#{directory}/#{name}" }).to have_attributes(content:)
      end
    end
  end

  RSpec.shared_examples 'expected files' do |files|
    it 'does not include other files' do
      other_files = service_binding_files.reject do |file|
        match = file.path.match(%r{^#{directory}/(.+)$})
        !match.nil? && !files.delete(match[1]).nil?
      end

      expect(files).to be_empty
      expect(other_files).to be_empty
    end
  end

  RSpec.describe ServiceBindingFilesBuilder do
    let(:service) { VCAP::CloudController::Service.make(label: 'service-name', tags: %w[a-service-tag another-service-tag]) }
    let(:plan) { VCAP::CloudController::ServicePlan.make(name: 'plan-name', service: service) }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(name: 'instance-name', tags: %w[an-instance-tag another-instance-tag], service_plan: plan) }
    let(:binding_name) { 'binding-name' }
    let(:credentials) do
      {
        string: 'a string',
        number: 42,
        boolean: true,
        array: %w[one two three],
        hash: {
          key: 'value'
        }
      }
    end
    let(:syslog_drain_url) { nil }
    let(:volume_mounts) { nil }
    let(:binding) do
      VCAP::CloudController::ServiceBinding.make(
        name: binding_name,
        credentials: credentials,
        service_instance: instance,
        syslog_drain_url: syslog_drain_url,
        volume_mounts: volume_mounts
      )
    end
    let(:app) { binding.app }
    let(:directory) { 'binding-name' }

    before do
      app.update(file_based_service_bindings_enabled: true)
    end

    describe '#build' do
      subject(:build) { ServiceBindingFilesBuilder.build(app) }

      it 'returns an array of Diego::Bbs::Models::File objects' do
        expect(build).to be_an(Array)
        expect(build).not_to be_empty
        expect(build).to all(be_a(Diego::Bbs::Models::File))
      end

      describe 'mapping rules for service binding files' do
        subject(:service_binding_files) { build }

        it 'puts all files into a directory named after the service binding' do
          expect(service_binding_files).not_to be_empty
          expect(service_binding_files).to all(have_attributes(path: match(%r{^binding-name/.+$})))
        end

        include_examples 'mapping of type and provider'
        include_examples 'mapping of binding metadata'
        include_examples 'mapping of instance metadata'
        include_examples 'mapping of plan metadata'
        include_examples 'mapping of tags'
        include_examples 'mapping of credentials'

        it 'omits null or empty array attributes' do
          expect(service_binding_files).not_to include(have_attributes(path: 'binding-name/syslog_drain_url'))
          expect(service_binding_files).not_to include(have_attributes(path: 'binding-name/volume_mounts'))
        end

        include_examples 'expected files', %w[type provider label binding-guid name binding-name instance-guid instance-name plan tags string number boolean array hash]

        context 'when binding_name is nil' do
          let(:binding_name) { nil }
          let(:directory) { 'instance-name' }

          include_examples 'mapping of type and provider'
          include_examples 'mapping of binding metadata', 'instance-name'
          include_examples 'mapping of instance metadata'
          include_examples 'mapping of plan metadata'
          include_examples 'mapping of tags'
          include_examples 'mapping of credentials'

          include_examples 'expected files', %w[type provider label binding-guid name instance-guid instance-name plan tags string number boolean array hash]
        end

        context 'when syslog_drain_url is set' do
          let(:syslog_drain_url) { 'https://syslog.drain' }

          it 'maps the attribute to a file' do
            expect(service_binding_files.find { |f| f.path == 'binding-name/syslog-drain-url' }).to have_attributes(content: 'https://syslog.drain')
          end

          include_examples 'mapping of type and provider'
          include_examples 'mapping of binding metadata'
          include_examples 'mapping of instance metadata'
          include_examples 'mapping of plan metadata'
          include_examples 'mapping of tags'
          include_examples 'mapping of credentials'

          include_examples 'expected files',
                           %w[type provider label binding-guid name binding-name instance-guid instance-name plan tags string number boolean array hash syslog-drain-url]
        end

        context 'when volume_mounts is set' do
          let(:volume_mounts) do
            [{
              container_dir: 'dir1',
              device_type: 'type1',
              mode: 'mode1',
              foo: 'bar'
            }, {
              container_dir: 'dir2',
              device_type: 'type2',
              mode: 'mode2',
              foo: 'baz'
            }]
          end

          it 'maps the attribute to a file' do
            expect(service_binding_files.find do |f|
              f.path == 'binding-name/volume-mounts'
            end).to have_attributes(content: '[{"container_dir":"dir1","device_type":"type1","mode":"mode1"},{"container_dir":"dir2","device_type":"type2","mode":"mode2"}]')
          end

          include_examples 'mapping of type and provider'
          include_examples 'mapping of binding metadata'
          include_examples 'mapping of instance metadata'
          include_examples 'mapping of plan metadata'
          include_examples 'mapping of tags'
          include_examples 'mapping of credentials'

          include_examples 'expected files',
                           %w[type provider label binding-guid name binding-name instance-guid instance-name plan tags string number boolean array hash volume-mounts]
        end

        context 'when the instance is user-provided' do
          let(:instance) { VCAP::CloudController::UserProvidedServiceInstance.make(name: 'upsi', tags: %w[an-upsi-tag another-upsi-tag]) }

          include_examples 'mapping of type and provider', 'user-provided'
          include_examples 'mapping of binding metadata'
          include_examples 'mapping of instance metadata', 'upsi'
          include_examples 'mapping of tags', '["an-upsi-tag","another-upsi-tag"]'
          include_examples 'mapping of credentials'

          include_examples 'expected files', %w[type provider label binding-guid name binding-name instance-guid instance-name tags string number boolean array hash]
        end

        context 'when there are duplicate keys at different levels' do
          let(:credentials) { { type: 'duplicate-type', name: 'duplicate-name', credentials: { password: 'secret' } } }

          include_examples 'mapping of type and provider' # no 'duplicate-type'
          include_examples 'mapping of binding metadata' # no 'duplicate-name'
          include_examples 'mapping of instance metadata'
          include_examples 'mapping of plan metadata'
          include_examples 'mapping of tags'
          include_examples 'mapping of credentials', { credentials: '{"password":"secret"}' }

          include_examples 'expected files', %w[type provider label binding-guid name binding-name instance-guid instance-name plan tags credentials]
        end

        context 'when there are duplicate binding names' do
          let(:binding_name) { 'duplicate-name' }

          before do
            VCAP::CloudController::ServiceBinding.make(app: app,
                                                       service_instance: VCAP::CloudController::UserProvidedServiceInstance.make(
                                                         space: app.space, name: 'duplicate-name'
                                                       ))
          end

          it 'raises an exception' do
            expect { service_binding_files }.to raise_error(ServiceBindingFilesBuilder::IncompatibleBindings, 'Duplicate binding name: duplicate-name')
          end
        end

        context 'when binding names violate the Service Binding Specification for Kubernetes' do
          let(:binding_name) { 'binding_name' }

          it 'raises an exception' do
            expect { service_binding_files }.to raise_error(ServiceBindingFilesBuilder::IncompatibleBindings, 'Invalid binding name: binding_name')
          end
        end

        context 'when the bindings exceed the maximum allowed bytesize' do
          let(:xxl_credentials) do
            c = {}
            value = 'v' * 1000
            1000.times do |i|
              c["key#{i}"] = value
            end
            c
          end

          before do
            allow_any_instance_of(ServiceBindingPresenter).to receive(:to_hash).and_wrap_original do |original|
              original.call.merge(credentials: xxl_credentials)
            end
          end

          it 'raises an exception' do
            expect { service_binding_files }.to raise_error(ServiceBindingFilesBuilder::IncompatibleBindings, /^Bindings exceed the maximum allowed bytesize of 1000000: \d+/)
          end
        end

        context 'when credential keys violate the Service Binding Specification for Kubernetes for binding entry file names' do
          let(:credentials) { { '../secret': 'hidden' } }

          it 'raises an exception' do
            expect { service_binding_files }.to raise_error(ServiceBindingFilesBuilder::IncompatibleBindings, 'Invalid file name: ../secret')
          end
        end
      end
    end
  end
end

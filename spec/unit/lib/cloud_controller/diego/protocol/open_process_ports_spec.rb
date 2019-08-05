require 'spec_helper'

module VCAP::CloudController
  module Diego
    class Protocol
      RSpec.describe OpenProcessPorts do
        describe '#to_a' do
          subject(:open_ports) { OpenProcessPorts.new(process).to_a }

          context 'when the process is docker' do
            let(:process) { ProcessModel.make(:docker, ports: ports, type: type) }

            context 'when the process has ports specified' do
              let(:ports) { [1111, 2222] }
              let(:type) { 'worker' }

              context 'when there is at least one route mapping with no port specified' do
                before do
                  RouteMappingModel.make(app: process.app, process_type: type, app_port: ProcessModel::NO_APP_PORT_SPECIFIED)
                end

                context 'when the Docker image exposes a port' do
                  before do
                    allow(process).to receive(:docker_ports).and_return([2222, 3333, 4444])
                  end

                  it 'uses the port exposed by the Docker image and the process ports' do
                    expect(open_ports).to contain_exactly(1111, 2222, 3333, 4444)
                  end
                end

                context 'when the Docker image does **not** expose a port' do
                  before do
                    allow(process).to receive(:docker_ports).and_return(nil)
                  end

                  it 'uses 8080 and the process ports' do
                    expect(open_ports).to contain_exactly(1111, 2222, 8080)
                  end
                end
              end

              context 'when all route mappings have ports specified' do
                before do
                  RouteMappingModel.make(app: process.app, process_type: type, app_port: 9999)
                end

                it 'uses the process ports' do
                  expect(open_ports).to contain_exactly(1111, 2222)
                end
              end
            end

            context 'when the process does not have ports specified, but is a web process' do
              let(:ports) { nil }
              let(:type) { ProcessTypes::WEB }

              context 'when there is at least one route mapping with no port specified' do
                before do
                  RouteMappingModel.make(app: process.app, process_type: type, app_port: ProcessModel::NO_APP_PORT_SPECIFIED)
                end

                context 'when the Docker image exposes a port' do
                  before do
                    allow(process).to receive(:docker_ports).and_return([3333, 4444])
                  end

                  it 'uses the port exposed by the Docker image' do
                    expect(open_ports).to contain_exactly(3333, 4444)
                  end
                end

                context 'when the Docker image does **not** expose a port' do
                  before do
                    allow(process).to receive(:docker_ports).and_return(nil)
                  end

                  it 'uses 8080' do
                    expect(open_ports).to contain_exactly(8080)
                  end
                end
              end

              context 'when all route mappings have ports specified' do
                before do
                  RouteMappingModel.make(app: process.app, process_type: type, app_port: 9999)
                end

                it 'uses 8080' do
                  expect(open_ports).to contain_exactly(8080)
                end
              end
            end

            context 'when the process does not have ports specified, and is not a web process' do
              let(:ports) { nil }
              let(:type) { 'worker' }

              context 'when there is at least one route mapping with no port specified' do
                before do
                  RouteMappingModel.make(app: process.app, process_type: type, app_port: ProcessModel::NO_APP_PORT_SPECIFIED)
                end

                context 'when the Docker image exposes a port' do
                  before do
                    allow(process).to receive(:docker_ports).and_return([3333, 4444])
                  end

                  it 'uses the port exposed by the Docker image' do
                    expect(open_ports).to contain_exactly(3333, 4444)
                  end
                end

                context 'when the Docker image does **not** expose a port' do
                  before do
                    allow(process).to receive(:docker_ports).and_return(nil)
                  end

                  it 'uses 8080' do
                    expect(open_ports).to contain_exactly(8080)
                  end
                end
              end

              context 'when all route mappings have ports specified' do
                before do
                  RouteMappingModel.make(app: process.app, process_type: type, app_port: 9999)
                end

                it 'does not open any ports' do
                  expect(open_ports).to be_empty
                end
              end
            end
          end

          context 'when the process is buildpack' do
            let(:process) { ProcessModel.make(ports: ports, type: type) }

            context 'when the process has ports specified' do
              let(:ports) { [1111, 2222] }
              let(:type) { 'worker' }

              it 'uses the specified ports' do
                expect(open_ports).to contain_exactly(1111, 2222)
              end
            end

            context 'when the process does not have ports specified, but is a web process' do
              let(:ports) { nil }
              let(:type) { ProcessTypes::WEB }

              it 'uses port 8080' do
                expect(open_ports).to contain_exactly(8080)
              end
            end

            context 'when the process does not have ports specified, and is not a web process' do
              let(:ports) { nil }
              let(:type) { 'worker' }

              it 'does not open any ports' do
                expect(open_ports).to be_empty
              end
            end
          end
        end
      end
    end
  end
end

require 'spec_helper'

module VCAP::CloudController
  module Diego
    class Protocol
      RSpec.describe OpenProcessPorts do
        describe '#to_a' do
          let(:process) do
            AppFactory.make(
              command: 'start_me',
              diego:   true,
              type:    type,
              ports:   ports,
              health_check_type: 'process'
            )
          end
          let(:type) { 'web' }
          let(:ports) { [1111, 2222] }

          subject(:open_ports) { OpenProcessPorts.new(process).to_a }

          context 'when the process has ports' do
            it 'returns those ports' do
              expect(open_ports).to eq([1111, 2222])
            end

            context 'but the ports it has is explicitly empty' do
              let(:ports) { [] }

              it 'respects the desire to have no ports' do
                expect(open_ports).to eq([])
              end
            end
          end

          context 'when process does not have ports defined' do
            let(:ports) { nil }

            context 'when this is a docker process' do
              before do
                allow(process).to receive(:docker_image).and_return('docker/image')
                allow(process).to receive(:docker_ports).and_return([123, 456])
              end

              it 'uses the saved docker ports' do
                expect(open_ports).to eq([123, 456])
              end
            end

            context 'when this is a buildpack process' do
              context 'when the type is web' do
                let(:type) { 'web' }

                it 'defaults to [8080]' do
                  expect(open_ports).to eq([8080])
                end
              end

              context 'when the type is not web' do
                let(:type) { 'other' }

                it 'default to []' do
                  expect(open_ports).to eq([])
                end
              end
            end
          end
        end
      end
    end
  end
end

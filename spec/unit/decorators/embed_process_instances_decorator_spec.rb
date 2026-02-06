require 'spec_helper'

module VCAP::CloudController
  RSpec.describe EmbedProcessInstancesDecorator do
    PROCESS = Struct.new(:guid)

    subject(:decorator) { EmbedProcessInstancesDecorator }

    describe '.decorate' do
      let(:process1) { PROCESS.new('process1-guid') }
      let(:process2) { PROCESS.new('process2-guid') }
      let(:instances_for_processes) do
        { process1.guid => { 0 => { state: 'RUNNING', since: 111 } }, process2.guid => { 1 => { state: 'STOPPED', since: 222 } } }
      end
      let(:instances_reporters) { instance_double(VCAP::CloudController::InstancesReporters) }

      before do
        CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
        allow(instances_reporters).to receive(:instances_for_processes).and_return(instances_for_processes)
      end

      context 'hash without resources (ProcessPresenter)' do
        let(:original_hash) do
          { guid: process1.guid, foo: 'foo', relationships: 'relationships', bar: 'bar' }
        end
        let(:expected_result) do
          { guid: process1.guid, foo: 'foo', process_instances: [{ index: 0, state: 'RUNNING', since: 111 }], relationships: 'relationships', bar: 'bar' }
        end

        it 'decorates the given hash with process instances' do
          hash = subject.decorate(original_hash, [process1])
          expect(hash).to eq(expected_result)
          expect(hash.keys).to eq(expected_result.keys) # check order
        end

        context 'guid mismatch' do
          let(:original_hash) do
            { guid: 'mismatching-guid', foo: 'foo', relationships: 'relationships', bar: 'bar' }
          end
          let(:expected_result) do
            { guid: 'mismatching-guid', foo: 'foo', process_instances: [], relationships: 'relationships', bar: 'bar' }
          end

          it 'decorates the given hash with an empty process instances array' do
            hash = subject.decorate(original_hash, [process1])
            expect(hash).to eq(expected_result)
            expect(hash.keys).to eq(expected_result.keys) # check order
          end
        end
      end

      context 'hash with resources (PaginatedListPresenter)' do
        let(:original_hash) do
          { resources: [
            { guid: process1.guid, foo: 'foo1', relationships: 'relationships1', bar: 'bar1' },
            { guid: process2.guid, foo: 'foo2', relationships: 'relationships2', bar: 'bar2' }
          ] }
        end
        let(:expected_result) do
          { resources: [
            { guid: process1.guid, foo: 'foo1', process_instances: [{ index: 0, state: 'RUNNING', since: 111 }], relationships: 'relationships1', bar: 'bar1' },
            { guid: process2.guid, foo: 'foo2', process_instances: [{ index: 1, state: 'STOPPED', since: 222 }], relationships: 'relationships2', bar: 'bar2' }
          ] }
        end

        it 'decorates the given hash with process instances' do
          hash = subject.decorate(original_hash, [process1, process2])
          expect(hash).to eq(expected_result)
          expect(hash[:resources].flat_map(&:keys)).to eq(expected_result[:resources].flat_map(&:keys)) # check order
        end
      end
    end

    describe '.match?' do
      it 'matches embed arrays containing "process_instances"' do
        expect(decorator.match?(%w[foo process_instances bar])).to be(true)
      end

      it 'does not match other embed arrays' do
        expect(decorator.match?(%w[foo bar])).not_to be(true)
      end
    end
  end
end

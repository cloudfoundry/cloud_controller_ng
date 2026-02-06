module VCAP::CloudController
  class EmbedProcessInstancesDecorator
    class << self
      def match?(embed)
        embed&.include?('process_instances')
      end

      def decorate(hash, processes)
        instances_reporters = CloudController::DependencyLocator.instance.instances_reporters
        instances = instances_reporters.instances_for_processes(processes)

        if hash.key?(:resources)
          # Decorate PaginatedListPresenter
          processes.each do |process|
            resource_index = hash[:resources].find_index { |resource| resource[:guid] == process.guid }
            next unless resource_index # Should not happen...

            hash[:resources][resource_index] = embed_process_instances(hash[:resources][resource_index], process_instances(instances, process.guid))
          end
        else
          # Decorate ProcessPresenter
          hash = embed_process_instances(hash, process_instances(instances, hash[:guid]))
        end

        hash
      end

      private

      def process_instances(instances, process_guid)
        instances[process_guid]&.map do |index, instance|
          {
            index: index,
            state: instance[:state],
            since: instance[:since]
          }
        end || []
      end

      def embed_process_instances(resource_hash, process_instances)
        hash_as_array = resource_hash.to_a
        before_relationships = hash_as_array.index { |k, _| k == :relationships } || hash_as_array.length
        hash_as_array.insert(before_relationships, [:process_instances, process_instances])
        hash_as_array.to_h
      end
    end
  end
end

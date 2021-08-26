require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class ProcessListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, eager_loaded_associations: [])
        filter(message, process_dataset(eager_loaded_associations))
      end

      def fetch_for_spaces(message, space_guids:, eager_loaded_associations: [])
        filter(message, process_dataset(eager_loaded_associations).where(Sequel.qualify(:space, :guid) => space_guids))
      end

      def fetch_for_app(message, eager_loaded_associations: [])
        app = AppModel.where(guid: message.app_guid).first
        return nil unless app

        [app, filter(message, app.processes_dataset.eager(eager_loaded_associations))]
      end

      private

      def process_dataset(eager_loaded_associations)
        ProcessModel.dataset.
          eager(eager_loaded_associations).
          eager(:desired_droplet).
          eager_graph_with_options({ space: :organization }, join_type: :inner)
      end

      def filter(message, dataset)
        dataset = dataset.where(type: message.types) if message.requested?(:types)

        if message.requested?(:space_guids)
          dataset = dataset.where(Sequel.qualify(:space, :guid) => message.space_guids)
        end

        if message.requested?(:organization_guids)
          dataset = dataset.where(Sequel.qualify(:organization, :guid) => message.organization_guids)
        end

        if message.requested?(:app_guids)
          dataset = dataset.where(app_guid: message.app_guids)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: ProcessLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: ProcessModel,
          )
        end

        super(message, dataset, ProcessModel)
      end
    end
  end
end

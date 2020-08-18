require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class DeploymentListFetcher < BaseListFetcher
    class << self
      def fetch_all(message)
        filter(message, AppModel.select(:id))
      end

      def fetch_for_spaces(message, space_guids:)
        app_dataset = AppModel.where(space_guid: space_guids)
        filter(message, app_dataset)
      end

      private

      attr_reader :message

      def filter(message, app_dataset)
        dataset = filter_deployment_dataset(message, DeploymentModel.dataset)

        if message.requested? :app_guids
          app_dataset = app_dataset.where(guid: message.app_guids)
        end

        dataset = dataset.where(app: app_dataset)
        super(message, dataset, DeploymentModel)
      end

      def filter_deployment_dataset(message, dataset)
        if message.requested? :states
          dataset = dataset.where(state: message.states)
        end

        if message.requested? :status_reasons
          dataset = NullFilterQueryGenerator.add_filter(dataset, :status_reason, message.status_reasons)
        end

        if message.requested? :status_values
          dataset = dataset.where(status_value: message.status_values)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: DeploymentLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: DeploymentModel,
          )
        end
        dataset
      end
    end
  end
end

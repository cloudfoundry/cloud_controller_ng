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

        app_dataset = app_dataset.where(guid: message.app_guids) if message.requested? :app_guids

        dataset = dataset.where(app: app_dataset)
        super(message, dataset, DeploymentModel)
      end

      def filter_deployment_dataset(message, dataset)
        dataset = dataset.where(state: message.states) if message.requested? :states

        dataset = NullFilterQueryGenerator.add_filter(dataset, :status_reason, message.status_reasons) if message.requested? :status_reasons

        dataset = dataset.where(status_value: message.status_values) if message.requested? :status_values

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: DeploymentLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: DeploymentModel
          )
        end
        dataset
      end
    end
  end
end

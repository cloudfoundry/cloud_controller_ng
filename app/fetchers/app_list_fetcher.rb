require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class AppListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, eager_loaded_associations: [])
        dataset = AppModel.dataset.eager(eager_loaded_associations)
        filter(message, dataset)
      end

      def fetch(message, space_guids, eager_loaded_associations: [])
        dataset = AppModel.where(space_guid: space_guids).eager(eager_loaded_associations)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:names)
          dataset = dataset.where(name: message.names)
        end

        if message.requested?(:space_guids)
          dataset = dataset.where(space_guid: message.space_guids)
        end

        if message.requested?(:organization_guids)
          dataset = dataset.
                    join(:spaces, guid: :space_guid).
                    join(:organizations, id: :organization_id).
                    where(Sequel[:organizations][:guid] => message.organization_guids).
                    qualify(:apps)
        end

        if message.requested?(:stacks)
          buildpack_lifecycle_data_dataset = NullFilterQueryGenerator.add_filter(
            BuildpackLifecycleDataModel.dataset,
            :stack,
            message.stacks
          )

          dataset = dataset.where(guid: buildpack_lifecycle_data_dataset.map(&:app_guid))
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: AppModel,
          )
        end

        if message.requested?(:lifecycle_type)
          if message.lifecycle_type == BuildpackLifecycleDataModel::LIFECYCLE_TYPE
            dataset = dataset.where(
              guid: BuildpackLifecycleDataModel.
              select(:app_guid).
              where(Sequel.~(app_guid: nil)).
              map(&:app_guid)
            )
          elsif message.lifecycle_type == DockerLifecycleDataModel::LIFECYCLE_TYPE
            dataset = dataset.exclude(
              guid: BuildpackLifecycleDataModel.
              select(:app_guid).
              where(Sequel.~(app_guid: nil)).
              map(&:app_guid)
            )
          end
        end

        dataset = super(message, dataset, AppModel)

        dataset.eager(:processes)
      end
    end
  end
end

require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class AppRevisionsListFetcher < BaseListFetcher
    class << self
      def fetch(app, message)
        filter(message, app)
      end

      def fetch_deployed(app)
        processes = ProcessModel.where(app_guid: app.guid, state: 'STARTED')

        revisions = processes.map(&:revision_guid).compact

        RevisionModel.where(guid: revisions)
      end

      private

      def filter(message, app)
        dataset = RevisionModel.where(Sequel[:revisions][:app_guid] => app.guid)

        if message.requested?(:versions)
          dataset = dataset.where(Sequel[:revisions][:app_guid] => app.guid, version: message.versions)
        end

        if message.requested?(:deployable)
          dataset = dataset.
                    join(:droplets, guid: :droplet_guid).
                    where(Sequel[:droplets][:state] => DropletModel::STAGED_STATE).
                    qualify(:revisions)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: RevisionLabelModel,
            resource_dataset: dataset.qualify,
            requirements: message.requirements,
            resource_klass: RevisionModel,
          )
        end

        super(message, dataset, RevisionModel)
      end
    end
  end
end

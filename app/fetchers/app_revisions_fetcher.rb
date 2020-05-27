module VCAP::CloudController
  class AppRevisionsFetcher
    def self.fetch(app, message)
      dataset = RevisionModel.where(Sequel[:revisions][:app_guid] => app.guid)

      if message.requested?(:versions)
        dataset = dataset.where(Sequel[:revisions][:app_guid] => app.guid, version: message.versions)
      end

      if message.requested?(:deployable)
        dataset = dataset.join(:droplets, guid: :droplet_guid).where(Sequel[:revisions][:app_guid] => app.guid, Sequel[:droplets][:state] => DropletModel::STAGED_STATE)
      end

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: RevisionLabelModel,
          resource_dataset: dataset.qualify,
          requirements: message.requirements,
          resource_klass: RevisionModel,
        )
      end

      dataset
    end

    def self.fetch_deployed(app)
      processes = ProcessModel.where(app_guid: app.guid, state: 'STARTED')

      revisions = processes.map(&:revision_guid).compact

      RevisionModel.where(guid: revisions)
    end
  end
end

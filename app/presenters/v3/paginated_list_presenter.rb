require 'presenters/v3/droplet_presenter'
require 'presenters/v3/package_presenter'
require 'presenters/v3/process_presenter'

module VCAP::CloudController
  class PaginatedListPresenter
    PRESENTERS = {
      'App' => VCAP::CloudController::ProcessPresenter,
      'DropletModel' => VCAP::CloudController::DropletPresenter,
      'PackageModel' => VCAP::CloudController::PackagePresenter,
    }.freeze

    def initialize(dataset, base_url, filters=nil)
      @dataset = dataset
      @base_url = base_url
      @filters = filters
    end

    def to_hash
      {
        pagination: PaginationPresenter.new.present_pagination_hash(@dataset, @base_url, @filters),
        resources: presented_resources
      }
    end

    def to_json
      MultiJson.dump(to_hash, pretty: true)
    end

    private

    def presented_resources
      @dataset.records.map { |resource| presenter.new(resource).to_hash }
    end

    def presenter
      class_name = @dataset.records.first.class.name
      PRESENTERS.fetch(class_name.demodulize, nil) ||
        "#{class_name}Presenter".constantize
    end
  end
end

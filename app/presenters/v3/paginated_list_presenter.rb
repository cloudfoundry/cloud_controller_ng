require 'presenters/v3/app_presenter'
require 'presenters/v3/droplet_presenter'
require 'presenters/v3/package_presenter'
require 'presenters/v3/process_presenter'
require 'presenters/v3/route_mapping_presenter'
require 'presenters/v3/task_presenter'

module VCAP::CloudController
  class PaginatedListPresenter
    PRESENTERS = {
      'App' => VCAP::CloudController::ProcessPresenter,
      'AppModel' => VCAP::CloudController::AppPresenter,
      'DropletModel' => VCAP::CloudController::DropletPresenter,
      'PackageModel' => VCAP::CloudController::PackagePresenter,
      'RouteMappingModel' => VCAP::CloudController::RouteMappingPresenter,
      'TaskModel' => VCAP::CloudController::TaskPresenter,
    }.freeze

    def initialize(dataset, base_url, message=nil)
      @dataset = dataset
      @base_url = base_url
      @message = message
    end

    def to_hash
      {
        pagination: PaginationPresenter.new.present_pagination_hash(paginator, @base_url, @message),
        resources: presented_resources
      }
    end

    private

    def presented_resources
      paginator.records.map { |resource| presenter.new(resource, show_secrets: false).to_hash }
    end

    def presenter
      class_name = paginator.records.first.class.name
      PRESENTERS.fetch(class_name.demodulize, nil) ||
        "#{class_name}Presenter".constantize
    end

    def paginator
      @paginator ||= SequelPaginator.new.get_page(@dataset, @message.try(:pagination_options))
    end
  end
end

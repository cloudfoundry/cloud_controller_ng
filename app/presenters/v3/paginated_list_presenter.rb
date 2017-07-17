require 'presenters/v3/app_presenter'
require 'presenters/v3/droplet_presenter'
require 'presenters/v3/isolation_segment_presenter'
require 'presenters/v3/package_presenter'
require 'presenters/v3/pagination_presenter'
require 'presenters/v3/process_presenter'
require 'presenters/v3/route_mapping_presenter'
require 'presenters/v3/service_binding_presenter'
require 'presenters/v3/task_presenter'
require 'presenters/v3/organization_presenter'
require 'presenters/v3/space_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class PaginatedListPresenter
        PRESENTERS = {
          'ProcessModel'          => VCAP::CloudController::Presenters::V3::ProcessPresenter,
          'AppModel'              => VCAP::CloudController::Presenters::V3::AppPresenter,
          'DropletModel'          => VCAP::CloudController::Presenters::V3::DropletPresenter,
          'IsolationSegmentModel' => VCAP::CloudController::Presenters::V3::IsolationSegmentPresenter,
          'Organization'          => VCAP::CloudController::Presenters::V3::OrganizationPresenter,
          'Space'                 => VCAP::CloudController::Presenters::V3::SpacePresenter,
          'PackageModel'          => VCAP::CloudController::Presenters::V3::PackagePresenter,
          'RouteMappingModel'     => VCAP::CloudController::Presenters::V3::RouteMappingPresenter,
          'ServiceBinding'        => VCAP::CloudController::Presenters::V3::ServiceBindingPresenter,
          'TaskModel'             => VCAP::CloudController::Presenters::V3::TaskPresenter,
        }.freeze

        def initialize(dataset:, path:, message: nil, show_secrets: false)
          @dataset      = dataset
          @path         = path
          @message      = message
          @show_secrets = show_secrets
        end

        def to_hash
          {
            pagination: PaginationPresenter.new.present_pagination_hash(paginator, @path, @message),
            resources:  presented_resources
          }
        end

        private

        def presented_resources
          paginator.records.map do |resource|
            presenter.new(resource, show_secrets: @show_secrets, censored_message: BasePresenter::REDACTED_LIST_MESSAGE).to_hash
          end
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
  end
end

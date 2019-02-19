require 'presenters/v3/feature_flag_presenter'
require 'messages/feature_flags_list_message'
require 'cloud_controller/paging/list_paginator'

class FeatureFlagsController < ApplicationController
  def index
    message = FeatureFlagsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    db_feature_flags = FeatureFlag.all
    dataset = FeatureFlag::DEFAULT_FLAGS.collect do |feature_flag_name, default_enabled_state|
      db_flag = db_feature_flags.find { |feature_flag| feature_flag.name == feature_flag_name.to_s }
      db_flag || FeatureFlag.new(name: feature_flag_name, enabled: default_enabled_state)
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::FeatureFlagPresenter,
      paginated_result: ListPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/feature_flags',
      message: message
    )
  end
end

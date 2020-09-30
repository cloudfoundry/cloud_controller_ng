require 'presenters/v3/feature_flag_presenter'
require 'messages/feature_flags_list_message'
require 'messages/feature_flags_update_message'
require 'actions/feature_flag_update'
require 'cloud_controller/paging/list_paginator'
require 'fetchers/feature_flag_list_fetcher'

class FeatureFlagsController < ApplicationController
  def index
    message = FeatureFlagsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = FeatureFlagListFetcher.fetch_all(message)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::FeatureFlagPresenter,
      paginated_result: ListPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/feature_flags',
      message: message
    )
  end

  def show
    flag = find_flag(hashed_params[:name])

    flag_not_found! unless flag

    render status: :ok, json: Presenters::V3::FeatureFlagPresenter.new(flag)
  end

  def update
    flag = find_flag(hashed_params[:name])
    flag_not_found! unless flag

    unauthorized! unless permission_queryer.can_write_globally?

    message = FeatureFlagsUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    flag = VCAP::CloudController::FeatureFlagUpdate.new.update(flag, message)
    render status: :ok, json: Presenters::V3::FeatureFlagPresenter.new(flag)
  rescue FeatureFlagUpdate::Error => e
    unprocessable!(e)
  end

  private

  def flag_not_found!
    resource_not_found!(:feature_flag)
  end

  def find_flag(flag_name)
    default_flag = FeatureFlag::DEFAULT_FLAGS.map do |name, value|
      if name.to_s == flag_name
        FeatureFlag.new(name: name.to_s, enabled: value)
      end
    end.compact

    FeatureFlag.find(name: flag_name) || default_flag.first
  end
end

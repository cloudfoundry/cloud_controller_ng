require 'fetchers/global_usage_summary_fetcher'
require 'presenters/v3/info_presenter'
require 'presenters/v3/info_usage_summary_presenter'

class InfoController < ApplicationController
  def v3_info
    info = Info.new
    populate_info_fields(info)
    osbapi_version_file = Rails.root.join('config/osbapi_version').to_s
    if File.exist?(osbapi_version_file)
      info.osbapi_version = File.read(osbapi_version_file).strip
    else
      info.osbapi_version = ''
      Rails.logger.warn("OSBAPI version file not found at #{osbapi_version_file}")
    end

    render status: :ok, json: VCAP::CloudController::Presenters::V3::InfoPresenter.new(info)
  end

  def show_usage_summary
    not_found! unless permission_queryer.can_read_globally?

    summary = VCAP::CloudController::GlobalUsageSummaryFetcher.summary

    render status: :ok, json: VCAP::CloudController::Presenters::V3::InfoUsageSummaryPresenter.new(summary)
  end

  private

  def populate_info_fields(info)
    config = VCAP::CloudController::Config.config

    info.build = config.get(:info, :build) || ''
    info.min_cli_version = config.get(:info, :min_cli_version) || ''
    info.min_recommended_cli_version = config.get(:info, :min_recommended_cli_version) || ''
    info.custom = config.get(:info, :custom) || {}
    info.description = config.get(:info, :description) || ''
    info.name = config.get(:info, :name) || ''
    info.version = config.get(:info, :version) || 0
    info.support_address = config.get(:info, :support_address) || ''
    info.request_rate_limiter_enabled = config.get(:rate_limiter, :enabled) || false
    info.request_rate_limiter_general_limit = config.get(:rate_limiter, :per_process_general_limit) || ''
    info.request_rate_limiter_reset_interval_in_mins = config.get(:rate_limiter, :reset_interval_in_minutes) || ''
  end
end

class Info
  attr_accessor :build, :min_cli_version, :min_recommended_cli_version, :custom, :description, :name, :version, :support_address, :osbapi_version, :request_rate_limiter_enabled,
                :request_rate_limiter_general_limit, :request_rate_limiter_reset_interval_in_mins
end

require 'presenters/v3/info_presenter'

class InfoController < ActionController::Base
  def show
    info = Info.new
    config = VCAP::CloudController::Config.config

    info.build = config.get(:info, :build) || ''
    info.min_cli_version = config.get(:info, :min_cli_version) || ''
    info.min_recommended_cli_version = config.get(:info, :min_recommended_cli_version) || ''
    info.custom = config.get(:info, :custom) || {}
    info.description = config.get(:info, :description) || ''
    info.name = config.get(:info, :name) || ''
    info.version = config.get(:info, :version) || 0
    info.support_address = config.get(:info, :support_address) || ''

    render status: :ok, json: VCAP::CloudController::Presenters::V3::InfoPresenter.new(info)
  end
end

class Info
  attr_accessor :build, :min_cli_version, :min_recommended_cli_version, :custom, :description, :name, :version, :support_address
end

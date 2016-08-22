require 'messages/isolation_segment_create_message'
require 'messages/isolation_segment_update_message'
require 'messages/isolation_segments_list_message'
require 'presenters/v3/isolation_segment_presenter'

class IsolationSegmentsController < ApplicationController
  def create
    unauthorized! unless roles.admin?

    message = IsolationSegmentCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    isolation_segment = nil
    IsolationSegmentModel.db.transaction do
      isolation_segment = IsolationSegmentModel.create(
        name: message.name,
      )
    end

    render status: :created, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment)
  rescue Sequel::ValidationFailed => e
    unprocessable!(e.message)
  end

  def show
    unauthorized! unless roles.admin?

    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    render status: :ok, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  end

  def index
    unauthorized! unless roles.admin?

    message = IsolationSegmentsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    invalid_param!(message.pagination_options.errors.full_messages) unless message.pagination_options.valid?

    dataset = filter(message, IsolationSegmentModel.dataset)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(dataset, '/v3/isolation_segments', message)
  end

  def destroy
    unauthorized! unless roles.admin?

    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    isolation_segment_model.db.transaction do
      isolation_segment_model.lock!
      isolation_segment_model.destroy
    end

    head :no_content
  end

  def update
    unauthorized! unless roles.admin?

    message = IsolationSegmentCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    isolation_segment_model.db.transaction do
      isolation_segment_model.lock!
      isolation_segment_model.name = message.name if message.requested?(:name)
      isolation_segment_model.save
    end

    isolation_segment_model.reload

    render status: :ok, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  rescue Sequel::ValidationFailed => e
    unprocessable!(e.message)
  end

  private

  def filter(message, dataset)
    if message.requested?(:names)
      dataset = dataset.where(name: message.names)
    end
    if message.requested?(:guids)
      dataset = dataset.where(guid: message.guids)
    end
    dataset
  end
end

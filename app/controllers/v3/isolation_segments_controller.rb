require 'messages/isolation_segment_create_message'
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
end

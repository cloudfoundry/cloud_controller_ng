require 'presenters/v3/service_usage_snapshot_presenter'
require 'presenters/v3/service_usage_snapshot_chunk_presenter'
require 'messages/service_usage_snapshots_create_message'
require 'messages/service_usage_snapshots_list_message'
require 'fetchers/service_usage_snapshot_list_fetcher'
require 'jobs/runtime/service_usage_snapshot_generator_job'

class ServiceUsageSnapshotsController < ApplicationController
  def index
    message = ServiceUsageSnapshotsListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    dataset = ServiceUsageSnapshot.where(guid: [])
    dataset = ServiceUsageSnapshotListFetcher.fetch_all(message, ServiceUsageSnapshot.dataset) if permission_queryer.can_read_globally?

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceUsageSnapshotPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/service_usage/snapshots',
      message: message
    )
  end

  def show
    snapshot_not_found! unless permission_queryer.can_read_globally?

    snapshot = ServiceUsageSnapshot.first(guid: hashed_params[:guid])
    snapshot_not_found! unless snapshot

    render status: :ok, json: Presenters::V3::ServiceUsageSnapshotPresenter.new(snapshot)
  end

  def create
    message = ServiceUsageSnapshotsCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unauthorized! unless permission_queryer.can_write_globally?

    existing_snapshot = ServiceUsageSnapshot.where(completed_at: nil).first
    raise CloudController::Errors::ApiError.new_from_details('ServiceUsageSnapshotGenerationInProgress') if existing_snapshot

    snapshot = ServiceUsageSnapshot.create(
      checkpoint_event_guid: nil,
      created_at: Time.now.utc,
      completed_at: nil,
      service_instance_count: 0,
      organization_count: 0,
      space_count: 0,
      chunk_count: 0
    )

    begin
      job = Jobs::Runtime::ServiceUsageSnapshotGeneratorJob.new(snapshot.guid)
      pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
    rescue StandardError
      snapshot.destroy
      raise
    end

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def chunks
    snapshot_not_found! unless permission_queryer.can_read_globally?

    snapshot = ServiceUsageSnapshot.first(guid: hashed_params[:guid])
    snapshot_not_found! unless snapshot

    unprocessable!('Snapshot is still processing') unless snapshot.complete?

    pagination_options = PaginationOptions.from_params(query_params)
    paginated_result = SequelPaginator.new.get_page(
      snapshot.service_usage_snapshot_chunks_dataset,
      pagination_options
    )

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceUsageSnapshotChunkPresenter,
      paginated_result: paginated_result,
      path: "/v3/service_usage/snapshots/#{snapshot.guid}/chunks"
    )
  end

  private

  def snapshot_not_found!
    resource_not_found!(:service_usage_snapshot)
  end
end

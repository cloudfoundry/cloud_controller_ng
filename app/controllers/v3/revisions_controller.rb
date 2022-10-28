require 'messages/revisions_update_message'
require 'actions/revisions_update'
require 'presenters/v3/revision_presenter'
require 'presenters/v3/revision_environment_variables_presenter'
require 'repositories/revision_event_repository'

class RevisionsController < ApplicationController
  def show
    revision = fetch_revision(hashed_params[:revision_guid])
    render status: :ok, json: Presenters::V3::RevisionPresenter.new(revision)
  end

  def update
    message = RevisionsUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    revision = fetch_revision(hashed_params[:revision_guid], needs_write_permissions: true)

    revision = RevisionsUpdate.new.update(revision, message)

    render status: :ok, json: Presenters::V3::RevisionPresenter.new(revision)
  end

  def show_environment_variables
    revision = fetch_revision(hashed_params[:revision_guid], needs_secrets_read_permission: true)
    Repositories::RevisionEventRepository.record_show_environment_variables(revision, revision.app, user_audit_info)
    render status: :ok, json: Presenters::V3::RevisionEnvironmentVariablesPresenter.new(revision)
  end

  private

  def fetch_revision(guid, needs_write_permissions: false, needs_secrets_read_permission: false)
    revision = RevisionModel.find(guid: guid)
    resource_not_found!(:revision) unless revision

    app = revision.app
    space = app.space
    resource_not_found!(:revision) unless permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! if needs_write_permissions && !permission_queryer.can_write_to_active_space?(space.id)
    suspended! if needs_write_permissions && !permission_queryer.is_space_active?(space.id)
    unauthorized! if needs_secrets_read_permission && !permission_queryer.can_read_secrets_in_space?(space.id, space.organization_id)

    revision
  end
end

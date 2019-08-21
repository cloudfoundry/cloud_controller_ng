require 'messages/user_create_message'
require 'messages/users_list_message'
require 'actions/user_create'
require 'presenters/v3/user_presenter'

class UsersController < ApplicationController
  def index
    message = UsersListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?
    users = fetch_readable_users
    user_guids = users.map(&:guid)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::UserPresenter,
      paginated_result: SequelPaginator.new.get_page(users, message.try(:pagination_options)),
      path: '/v3/users',
      message: message,
      extra_presenter_args: { uaa_users: uaa_users_info(user_guids) },
    )
  end

  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = UserCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    user = UserCreate.new.create(message: message)

    render status: :created, json: Presenters::V3::UserPresenter.new(user, uaa_users: uaa_users_info(user.guid))
  rescue UserCreate::Error => e
    unprocessable!(e)
  end

  private

  def fetch_readable_users
    if permission_queryer.can_read_secrets_globally?
      User.dataset
    else
      User.where(guid: current_user.guid)
    end
  end

  def uaa_users_info(user_guids)
    uaa_client = CloudController::DependencyLocator.instance.uaa_client
    uaa_client.users_for_ids([user_guids])
  end
end

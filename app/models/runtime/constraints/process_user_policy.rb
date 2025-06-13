class ProcessUserPolicy
  ERROR_MSG = 'invalid (requested user %<requested_user>s not allowed, permitted users are: %<allowed_users>s)'.freeze

  def initialize(process, allowed_users)
    @process = process
    @allowed_users = allowed_users
    @errors = process.errors
  end

  def validate
    return if @process.user.blank?
    return if @allowed_users.map(&:downcase).include?(@process.user.downcase)

    @errors.add(:user, sprintf(ERROR_MSG, requested_user: @process.user, allowed_users: @allowed_users.join(', ')))
  end
end

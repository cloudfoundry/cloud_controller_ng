class EnableSshPolicy
  def initialize(app)
    @errors = app.errors
    @app = app
  end

  def validate
    return unless @app.enable_ssh
    global_allow_ssh = VCAP::CloudController::Config.config[:allow_app_ssh_access]
    ssh_allowed = global_allow_ssh && @app.space.allow_ssh

    unless ssh_allowed
      @errors.add(:enable_ssh, 'enable_ssh must be false due to global allow_ssh setting')
    end
  end
end

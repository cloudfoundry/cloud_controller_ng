class EnableSshPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    if @app.modified?(:enable_ssh) && @app.enable_ssh
      global_allow_ssh = VCAP::CloudController::Config.config[:allow_app_ssh_access]

      if !global_allow_ssh
        @errors.add(:enable_ssh, 'must be false due to ssh being disabled globally')
      end

      if !@app.space.allow_ssh
        @errors.add(:enable_ssh, 'must be false due to ssh being disabled on space')
      end
    end
  end
end

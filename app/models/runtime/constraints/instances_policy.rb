class InstancesPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    if @app.instances < 0
      @errors.add(:instances, :less_than_zero)
    end
  end
end

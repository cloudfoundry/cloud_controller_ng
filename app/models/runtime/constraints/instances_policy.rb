class InstancesPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    if @app.instances < 1
      @errors.add(:instances, :less_than_one)
    end
  end
end

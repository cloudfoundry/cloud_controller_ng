class MinMemoryPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    @errors.add(:memory, :zero_or_less) unless @app.memory > 0
  end
end

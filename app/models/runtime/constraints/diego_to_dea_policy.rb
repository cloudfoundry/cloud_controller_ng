class DiegoToDeaPolicy
  def initialize(app, diego_to_dea_flag)
    @app = app
    @errors = app.errors
    @diego_to_dea_flag = diego_to_dea_flag
  end

  def validate
    return if !@diego_to_dea_flag || @app.route_mappings.nil?
    @errors.add(:diego_to_dea, 'Multiple app ports not allowed') if has_multiple_route_mappings?
  end

  private

  def has_multiple_route_mappings?
    @app.route_mappings.uniq(&:app_port).size > 1
  end
end

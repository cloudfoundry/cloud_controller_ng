class PortsPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    return if @app.ports.nil?
    return @errors.add(:ports, 'must be integers') unless all_ports_are_integers?
    @errors.add(:ports, 'must be in valid port range') unless all_ports_are_in_range?
  end

  private

  def all_ports_are_integers?
    @app.ports.all? { |port| port.is_a? Integer }
  end

  def all_ports_are_in_range?
    @app.ports.all? do |port|
      port > 0 && port <= 65535
    end
  end
end

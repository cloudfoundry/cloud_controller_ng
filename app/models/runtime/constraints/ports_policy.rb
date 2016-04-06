class PortsPolicy
  def initialize(app, changed_to_diego)
    @app = app
    @changed_to_diego = changed_to_diego
    @errors = app.errors
  end

  def validate
    return if @app.ports.nil? || @app.ports.empty?
    return @errors.add(:ports, 'Custom app ports supported for Diego only. Enable Diego for the app or remove custom app ports.') if !@app.diego
    return @errors.add(:ports, 'Maximum of 10 app ports allowed.') if ports_limit_exceeded?
    return @errors.add(:ports, 'must be integers') unless all_ports_are_integers?
    return @errors.add(:ports, 'Ports must be in the 1024-65535.') unless all_ports_are_in_range?
    @errors.add(:ports, 'App ports ports may not be removed while routes are mapped to them. '\
    'To change the app port a route is mapped to add the new ports to your app, '\
    'change the app port the route is mapped to, then remove unused app ports.') unless verify_ports
  end

  private

  def verify_ports
    return true if @changed_to_diego
    @app.route_mappings.each do |m|
      if m.user_provided_app_port.blank?
        return false unless @app.ports.include?(VCAP::CloudController::App::DEFAULT_HTTP_PORT)
      elsif !@app.ports.include?(m.app_port)
        return false
      end
    end
  end

  def all_ports_are_integers?
    @app.ports.all? { |port| port.is_a? Integer }
  end

  def all_ports_are_in_range?
    @app.ports.all? do |port|
      port > 1023 && port <= 65535
    end
  end

  def ports_limit_exceeded?
    @app.ports.length > 10
  end
end

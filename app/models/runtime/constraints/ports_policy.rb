class PortsPolicy
  def initialize(process, changed_to_diego)
    @process          = process
    @changed_to_diego = changed_to_diego
    @errors           = process.errors
  end

  def validate
    return if @process.ports.nil? || @process.ports.empty?
    return @errors.add(:ports, 'Custom app ports supported for Diego only. Enable Diego for the app or remove custom app ports.') if !@process.diego
    return @errors.add(:ports, 'Maximum of 10 app ports allowed.') if ports_limit_exceeded?
    return @errors.add(:ports, 'must be integers') unless all_ports_are_integers?
    return @errors.add(:ports, 'Ports must be in the 1024-65535.') unless all_ports_are_in_range?
    unless verify_ports
      @errors.add(:ports,
        'App ports ports may not be removed while routes are mapped to them. '\
        'To change the app port a route is mapped to add the new ports to your app, '\
        'change the app port the route is mapped to, then remove unused app ports.'
      )
    end
  end

  private

  def verify_ports
    return true if @changed_to_diego
    @process.route_mappings.each do |m|
      if m.app_port.blank?
        return false unless @process.ports.include?(VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT)
      elsif !@process.ports.include?(m.app_port)
        return false
      end
    end
  end

  def all_ports_are_integers?
    @process.ports.all? { |port| port.is_a? Integer }
  end

  def all_ports_are_in_range?
    @process.ports.all? do |port|
      port > 1023 && port <= 65535
    end
  end

  def ports_limit_exceeded?
    @process.ports.length > 10
  end
end

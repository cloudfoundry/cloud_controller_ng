class PropagateInstanceCredentials
  def execute(service_instance)
    service_instance.service_bindings.each do |binding|
      binding.credentials = service_instance.credentials
      binding.save
    end
  end
end

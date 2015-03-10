class ServiceBindingDelete
  def delete(service_binding_dataset)
    service_binding_dataset.destroy
  end
end

module VCAP::CloudController::RestController
  class SecureEagerLoader
    def eager_load_dataset(ds, starting_controller_class, default_visibility_filter, additional_visibility_filters, depth)
      eager_load_hash = build_eager_load_hash(
        starting_controller_class,
        ds.model,
        default_visibility_filter,
        additional_visibility_filters,
        depth,
      )

      ds.eager(eager_load_hash)
    end

    private

    def build_eager_load_hash(controller_class, model_class, default_visibility_filter, additional_visibility_filters, depth)
      associated_controller = controller_class

      # model_class cannot just be inferred from controller_class.model
      # because ServiceInstancesController can be used to present objects
      # from ManagedServiceInstance and ServiceInstance datasets.
      # Ideally that will not happen.
      associated_controller ||= VCAP::CloudController.controller_from_model_name(model_class.name)

      all_relationships = {}
      [associated_controller.to_one_relationships,
       associated_controller.to_many_relationships,
      ].each do |rel|
        all_relationships.merge!(rel) if rel && rel.any?
      end

      eager_load_hash = {}
      all_relationships.each do |relationship_name, association|
        association_name = association.association_name

        association_model_class = model_class.association_reflection(association_name)
        unless association_model_class
          # Since we are using STI in some models (e.g. Domain, ServiceInstance)
          # we are not able to find association on the parent class defined on a child class.
          # We are assuming that parent will have an association with a suffix.
          association_name = "#{association_name}_sti_eager_load".to_sym
          association_model_class = model_class.association_reflection(association_name)
        end

        unless association_model_class
          raise ArgumentError.new(
            "Cannot resolve association #{association_name} on #{model_class} " \
              'while trying to build eager loading hash'
          )
        end

        visibility_filter = default_visibility_filter
        additional_filter = additional_visibility_filters[relationship_name]
        if additional_filter
          visibility_filter = proc { |ds| additional_filter.call(default_visibility_filter.call(ds)) }
        end

        unless association.link_only?
          if depth > 0
            eager_load_hash[association_name] = {
              visibility_filter => build_eager_load_hash(
                nil,
                association_model_class.associated_class,
                default_visibility_filter,
                additional_visibility_filters,
                depth - 1,
              )
            }
          elsif association.is_a?(ControllerDSL::ToOneAttribute)
            # Preload one-to-one since we need to know record's guid
            eager_load_hash[association_name] = visibility_filter
          end
        end
      end

      eager_load_hash
    end
  end
end

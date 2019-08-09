module VCAP::CloudController
  class IncludeDecorator
    class << self
      def association_name
        raise NotImplementedError
      end

      def association_class
        raise NotImplementedError
      end

      def presenter
        raise NotImplementedError
      end

      def include_name
        association_name
      end

      def association_guid
        :"#{association_name}_guid"
      end

      def include_resource_name
        :"#{association_name}s"
      end

      def decorate(hash, resources)
        hash[:included] ||= {}
        association_guids = resources.map(&:"#{association_guid}").uniq
        associated_resources = association_class.where(guid: association_guids)

        presented_resources = associated_resources.map(&method(:present_associated_resource))
        hash[:included][include_resource_name] = presented_resources
        hash
      end

      def present_associated_resource(associated_resource)
        presenter.new(associated_resource).to_hash
      end
    end
  end
end

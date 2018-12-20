module VCAP::CloudController
  class PackageUpdate
    class InvalidPackage < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.package_update')
    end

    def update(package, message)
      if message.requested?(:metadata)
        package.db.transaction do
          LabelsUpdate.update(package, message.labels, PackageLabelModel)
          AnnotationsUpdate.update(package, message.annotations, PackageAnnotationModel)
        end
        @logger.info("Finished updating metadata on package #{package.guid}")
      end
      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end
  end
end

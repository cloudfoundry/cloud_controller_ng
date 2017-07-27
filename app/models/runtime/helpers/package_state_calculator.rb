module VCAP::CloudController
  class PackageStateCalculator
    def initialize(process)
      @latest_build = process.latest_build
      @latest_droplet = process.latest_droplet
      @current_droplet = process.current_droplet
      @latest_package = process.latest_package
    end

    def calculate
      if process_has_package || process_has_droplet
        return 'FAILED' if package_failed_upload || last_build_failed || last_droplet_failed
        return 'STAGED' if (process_has_droplet || process_has_build) &&
          build_completed &&
          latest_droplet_is_current
      end
      'PENDING'
    end

    private

    def build_completed
      @latest_build.nil? || @latest_build.staged?
    end

    def last_build_failed
      @latest_build && @latest_build.failed?
    end

    def last_droplet_failed
      @latest_droplet && @latest_droplet.failed?
    end

    def latest_droplet_is_current
      @latest_droplet == @current_droplet && !newer_package_than_droplet
    end

    def process_has_package
      @latest_package.present?
    end

    def process_has_droplet
      @latest_droplet.present?
    end

    def process_has_build
      @latest_build.present?
    end

    def newer_package_than_droplet
      !process_has_droplet ||
        process_has_package &&
        @current_droplet.try(:package) != @latest_package &&
        @latest_package.created_at >= @latest_droplet.created_at
    end

    def package_failed_upload
      package_for_latest_droplet = @latest_package == @latest_droplet.try(:package)
      if package_for_latest_droplet || newer_package_than_droplet
        @latest_package.try(:state) == PackageModel::FAILED_STATE
      end
    end
  end
end

module Fog
  module Google
    class Compute
      class Images < Fog::Collection
        model Fog::Google::Compute::Image

        # NOTE: some of these operating systems are premium and users will be
        # charged a license fee beyond the base Google Compute Engine VM
        # charges. See https://cloud.google.com/compute/docs/operating-systems/
        # for more info.
        GLOBAL_PROJECTS = %w(
          centos-cloud
          cos-cloud
          debian-cloud
          fedora-coreos-cloud
          rhel-cloud
          rhel-sap-cloud
          rocky-linux-cloud
          suse-cloud
          suse-sap-cloud
          ubuntu-os-cloud
          ubuntu-os-pro-cloud
          windows-cloud
          windows-sql-cloud
        ).freeze

        def all(opts = {})
          items = []
          all_projects.each do |project|
            begin
              next_page_token = nil
              loop do
                opts[:page_token] = next_page_token
                data = service.list_images(project, **opts)
                images = data.items&.map(&:to_h) || []
                # Keep track of the project in which we found the image(s)
                images.each { |img| img.merge!(:project => project) }
                items.concat(images)
                next_page_token = data.next_page_token
                break if next_page_token.nil? || next_page_token.empty?
              end
            rescue ::Google::Apis::ClientError => e
              raise e unless e.status_code == 404
              # Not everyone has access to every Global Project. Requests
              # return 404 if you don't have access.
              next
            end
          end
          load(items)
        end

        # Only return the non-deprecated list of images
        def current
          all.reject(&:deprecated)
        end

        def get(identity, project = nil)
          if project
            begin
              image = service.get_image(identity, project).to_h
              # TODO: Remove response modification - see #405
              image[:project] = project
              return new(image)
            rescue ::Google::Apis::ClientError => e
              raise e unless e.status_code == 404
              nil
            end
          elsif identity
            projects = all_projects
            projects.each do |proj|
              begin
                response = service.get_image(identity, proj).to_h
                # TODO: Remove response modification - see #405
                response[:project] = proj
                image = response
                return new(image)
              rescue ::Google::Apis::ClientError => e
                next if e.status_code == 404
                break
              end
            end
            # If nothing is found - return nil
            nil
          end
        end

        def get_from_family(family, project = nil)
          project.nil? ? projects = all_projects : projects = [project]
          data = nil

          projects.each do |proj|
            begin
              data = service.get_image_from_family(family, proj).to_h
              data[:project] = proj
            rescue ::Google::Apis::ClientError => e
              next if e.status_code == 404
              break
            end
          end
          return nil if data.nil?
          new(data)
        end

        private

        def all_projects
          # Search own project before global projects
          project_list = [service.project] + GLOBAL_PROJECTS + service.extra_global_projects
          unless service.exclude_projects.empty?
            project_list.delete_if { |project| service.exclude_projects.include?(project) }
          end
          project_list
        end
      end
    end
  end
end

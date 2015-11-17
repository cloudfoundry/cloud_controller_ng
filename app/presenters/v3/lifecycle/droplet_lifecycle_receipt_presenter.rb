module VCAP
  module CloudController
    class DropletLifecycleReceiptPresenter
      def result(droplet)
        {
          buildpack: droplet.buildpack_receipt_buildpack,
          stack:     droplet.buildpack_receipt_stack_name,
        }
      end

      def links(droplet)
        buildpack_link = nil
        if droplet.buildpack_receipt_buildpack_guid
          buildpack_link = {
            href: "/v2/buildpacks/#{droplet.buildpack_receipt_buildpack_guid}"
          }
        end

        {
          buildpack: buildpack_link
        }
      end
    end
  end
end

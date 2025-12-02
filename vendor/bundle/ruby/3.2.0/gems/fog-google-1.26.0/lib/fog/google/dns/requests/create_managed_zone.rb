require "date"
module Fog
  module Google
    class DNS
      ##
      # Creates a new Managed Zone.
      #
      # @see https://developers.google.com/cloud-dns/api/v1/managedZones/create
      class Real
        def create_managed_zone(name, dns_name, description)
          mngd_zone = ::Google::Apis::DnsV1::ManagedZone.new
          mngd_zone.name = name
          mngd_zone.dns_name = dns_name
          mngd_zone.description = description

          @dns.create_managed_zone(@project, mngd_zone)
        end
      end

      class Mock
        def create_managed_zone(_name, _dns_name, _description)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end

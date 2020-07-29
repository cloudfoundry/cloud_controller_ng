module VCAP
  module CloudController
    class ServiceCredentialBindingListFetcher
      def fetch(space_guids:)
        case space_guids
        when :all
          ServiceCredentialBinding::View.dataset
        else
          ServiceCredentialBinding::View.where { Sequel[:space_guid] =~ space_guids }
        end
      end
    end
  end
end

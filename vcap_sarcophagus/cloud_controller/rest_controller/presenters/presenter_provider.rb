module CloudController
  module Presenters
    module V2
      module PresenterProvider
        def self.presenter_for(obj)
          presenters.fetch(obj.class.name, DefaultPresenter).new
        end

        def present_for_class(klass)
          PresenterProvider.presenters[klass] = self
        end

        def self.presenters
          @presenters ||= {}
        end
      end
    end
  end
end

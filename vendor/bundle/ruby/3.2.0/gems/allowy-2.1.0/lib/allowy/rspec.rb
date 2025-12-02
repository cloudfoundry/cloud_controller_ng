require 'active_support/concern'
require 'allowy/matchers'

module Allowy

  module ControllerAuthorizationMacros
    extend ActiveSupport::Concern

    def allowy
      @controller.current_allowy
    end


    def should_authorize_for(*args)
      expect(allowy).to receive(:authorize!).with(*args)
    end

    def should_not_authorize_for(*args)
      expect(allowy).not_to receive(:authorize!).with(*args)
    end

    module ClassMethods
      def ignore_authorization!
        before(:each) do
          registry = double 'Registry'
          allow(registry).to receive_messages(:can? => true, :cannot? => false, :authorize! => nil, access_control_for!: registry)
          allow(@controller).to receive(:current_allowy).and_return registry
        end
      end
    end
  end

end

RSpec.configure do |config|
  config.include Allowy::ControllerAuthorizationMacros, :type => :controller
end


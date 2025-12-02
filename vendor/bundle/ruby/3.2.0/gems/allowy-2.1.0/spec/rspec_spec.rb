require 'spec_helper'
require 'allowy/rspec'

module Allowy
  describe ControllerAuthorizationMacros do
    include ControllerAuthorizationMacros
    before { @controller = double("FakeController") }

    ignore_authorization!

    it "aliases allowy as the current_allowy of the controller" do
      allowy.should === @controller.current_allowy
    end

    describe "authorize_for matcher" do
      it "works when authorised" do
        should_authorize_for(:create, 123)
        allowy.authorize!(:create, 123)
      end

      it "works when not authorised" do
        should_not_authorize_for(:create, 123)
        allowy.authorize!(:edit, 123)
      end
    end

  end
end

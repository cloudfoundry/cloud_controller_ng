# frozen_string_literal: true

require_relative 'allowy_spec_helper'

module Allowy
  class SampleContext
    include Context
  end

  RSpec.describe Context do
    subject(:sample_context) { SampleContext.new }

    let(:access) { double('Access') }

    it 'creates a registry' do
      expect(Registry).to receive(:new).with(sample_context).and_call_original
      sample_context.current_allowy
    end

    it 'checks using can?' do
      expect(sample_context.current_allowy).to receive(:access_control_for!).with(123).and_return(access)
      expect(access).to receive(:can?).with(:edit, 123)
      sample_context.can?(:edit, 123)
    end

    it 'checks using cannot?' do
      expect(sample_context.current_allowy).to receive(:access_control_for!).with(123).and_return(access)
      expect(access).to receive(:cannot?).with(:edit, 123)
      sample_context.cannot?(:edit, 123)
    end

    it 'calls authorize!' do
      expect(access).to receive(:authorize!).with(:edit, 123)
      allow(sample_context.current_allowy).to receive(:access_control_for!).and_return(access)
      sample_context.authorize!(:edit, 123)
    end
  end
end

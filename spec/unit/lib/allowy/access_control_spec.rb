# frozen_string_literal: true

require_relative 'allowy_spec_helper'

module Allowy
  RSpec.describe 'checking permissions' do
    let(:access) { SampleAccess.new(123) }

    describe '#context as an arbitrary object' do
      subject { access.context }

      it 'returns the context passed to initialize' do
        expect(subject.to_s).to eq('123')
      end

      it 'context is not zero' do
        expect(subject.zero?).to be(false)
      end

      it 'can access the context in permission check' do
        expect(access.can?(:context_is_123, nil)).to be(true)
      end
    end

    describe '#can?' do
      it 'returns true when permission allows' do
        expect(access.can?(:read, 'allow')).to be(true)
      end

      it 'returns false when permission denies' do
        expect(access.can?(:read, 'deny')).to be(false)
      end
    end

    describe '#cannot?' do
      it 'returns false when permission allows' do
        expect(access.cannot?(:read, 'allow')).to be(false)
      end

      it 'returns true when permission denies' do
        expect(access.cannot?(:read, 'deny')).to be(true)
      end
    end

    it 'passes extra parameters' do
      expect(access.can?(:extra_params, 'same', bar: 'same')).to be(true)
    end

    it 'denies with early termination' do
      expect(access.can?(:early_deny, 'foo')).to be(false)
      expect(access.can?(:early_deny, 'xx')).to be(false)
    end

    it 'raises if no permission defined' do
      expect { access.can?(:write, 'allow') }.to raise_error(UndefinedAction) do |err|
        expect(err.message).to include('write?')
      end
    end

    describe '#authorize!' do
      it 'raises AccessDenied when not authorized' do
        expect { access.authorize!(:read, 'deny') }.to raise_error(AccessDenied) do |err|
          expect(err.message).not_to be_empty
          expect(err.action).to eq(:read)
          expect(err.subject).to eq('deny')
        end
      end

      it 'does not raise when authorized' do
        expect { access.authorize!(:read, 'allow') }.not_to raise_error
      end

      it 'raises with payload on early termination' do
        expect { access.authorize!(:early_deny, 'subject') }.to raise_error(AccessDenied) do |err|
          expect(err.message).not_to be_empty
          expect(err.action).to eq(:early_deny)
          expect(err.subject).to eq('subject')
          expect(err.payload).to eq('early terminate: subject')
        end
      end
    end
  end
end

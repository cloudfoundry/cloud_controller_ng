require 'spec_helper'

module VCAP::CloudController
  RSpec.describe StackStateValidator do
    describe '.validate_for_new_app!' do
      context 'when stack is Active' do
        let(:stack) { Stack.make(state: StackStates::STACK_ACTIVE, description: 'My ACTIVE stack') }

        it 'returns empty warnings' do
          result = StackStateValidator.validate_for_new_app!(stack)
          expect(result).to eq([])
        end

        it 'does not raise an error' do
          expect { StackStateValidator.validate_for_new_app!(stack) }.not_to raise_error
        end
      end

      context 'when stack is DEPRECATED' do
        let(:stack) { Stack.make(state: StackStates::STACK_DEPRECATED, description: 'My DEPRECATED stack') }

        it 'returns a warning message' do
          result = StackStateValidator.validate_for_new_app!(stack)
          expect(result).to be_an(Array)
          expect(result.size).to eq(1)
          expect(result.first).to include("Stack '#{stack.name}' is deprecated and will be removed in the future. #{stack.description}")
        end

        it 'returns a warning message with stack name' do
          result = StackStateValidator.validate_for_new_app!(stack)
          warning = result.first
          expect(warning).to include(stack.name)
          expect(warning).to include(stack.description)
          expect(warning).to include('deprecated')
        end

        it 'does not raise an error' do
          expect { StackStateValidator.validate_for_new_app!(stack) }.not_to raise_error
        end
      end

      context 'when stack is RESTRICTED' do
        let(:stack) { Stack.make(state: StackStates::STACK_RESTRICTED, description: 'My RESTRICTED stack') }

        it 'raise RestrictedStackError' do
          expect do
            StackStateValidator.validate_for_new_app!(stack)
          end.to raise_error(StackStateValidator::RestrictedStackError, /Stack '#{stack.name}' is restricted and cannot be used for staging new applications./)
        end

        it 'includes stack name in error message' do
          expect do
            StackStateValidator.validate_for_new_app!(stack)
          end.to raise_error(StackStateValidator::RestrictedStackError, /#{stack.name}/)
        end

        it 'includes stack description in error message' do
          expect do
            StackStateValidator.validate_for_new_app!(stack)
          end.to raise_error(StackStateValidator::RestrictedStackError, /#{stack.description}/)
        end

        it 'raises RestrictedStackError which is a StackStateValidator::Error' do
          expect do
            StackStateValidator.validate_for_new_app!(stack)
          end.to raise_error(StackStateValidator::StackValidationError)
        end
      end

      context 'when stack is DISABLED' do
        let(:stack) { Stack.make(state: StackStates::STACK_DISABLED, description: 'My DEPRECATED stack') }

        it 'returns a disabled error message' do
          expect do
            StackStateValidator.validate_for_new_app!(stack)
          end.to raise_error(StackStateValidator::DisabledStackError, /Stack '#{stack.name}' is disabled and cannot be used for staging new applications./)
        end

        it 'includes stack name in error message' do
          expect do
            StackStateValidator.validate_for_new_app!(stack)
          end.to raise_error(StackStateValidator::DisabledStackError, /#{stack.name}/)
        end

        it 'includes stack description in error message' do
          expect do
            StackStateValidator.validate_for_new_app!(stack)
          end.to raise_error(StackStateValidator::DisabledStackError, /#{stack.description}/)
        end
      end
    end

    describe '.validate_for_restaging_app!' do
      context 'when stack is Active' do
        let(:stack) { Stack.make(state: StackStates::STACK_ACTIVE, description: 'My ACTIVE stack') }

        it 'for restaging returns empty warnings' do
          result = StackStateValidator.validate_for_restaging!(stack)
          expect(result).to eq([])
        end

        it 'does not raise an error' do
          expect { StackStateValidator.validate_for_new_app!(stack) }.not_to raise_error
        end
      end

      context 'when stack is DEPRECATED' do
        let(:stack) { Stack.make(state: StackStates::STACK_DEPRECATED, description: 'My DEPRECATED stack') }

        it 'returns a warning message' do
          result = StackStateValidator.validate_for_restaging!(stack)
          expect(result).to be_an(Array)
          expect(result.size).to eq(1)
          expect(result.first).to include("Stack '#{stack.name}' is deprecated and will be removed in the future. #{stack.description}")
        end

        it 'returns a warning message with stack name' do
          result = StackStateValidator.validate_for_restaging!(stack)
          warning = result.first
          expect(warning).to include(stack.name)
          expect(warning).to include(stack.description)
          expect(warning).to include('deprecated')
        end

        it 'does not raise an error' do
          expect { StackStateValidator.validate_for_restaging!(stack) }.not_to raise_error
        end
      end

      context 'when stack is RESTRICTED' do
        let(:stack) { Stack.make(state: StackStates::STACK_RESTRICTED, description: 'My RESTRICTED stack') }

        it 'returns empty warnings' do
          result = StackStateValidator.validate_for_restaging!(stack)
          expect(result).to eq([])
        end

        it 'does not raise an error' do
          expect { StackStateValidator.validate_for_restaging!(stack) }.not_to raise_error
        end
      end

      context 'when stack is DISABLED' do
        let(:stack) { Stack.make(state: StackStates::STACK_DISABLED, description: 'My DEPRECATED stack') }

        it 'returns a disabled error message' do
          expect do
            StackStateValidator.validate_for_restaging!(stack)
          end.to raise_error(StackStateValidator::DisabledStackError, /Stack '#{stack.name}' is disabled and cannot be used for staging new applications./)
        end

        it 'includes stack name in error message' do
          expect do
            StackStateValidator.validate_for_restaging!(stack)
          end.to raise_error(StackStateValidator::DisabledStackError, /#{stack.name}/)
        end

        it 'includes stack description in error message' do
          expect do
            StackStateValidator.validate_for_restaging!(stack)
          end.to raise_error(StackStateValidator::DisabledStackError, /#{stack.description}/)
        end
      end
    end

    describe '.build_deprecation_warning' do
      let(:stack) { Stack.make(name: 'cflinuxfs3', description: 'End of life December 2025') }

      it 'returns formatted warning string' do
        warning = StackStateValidator.build_deprecation_warning(stack)
        expect(warning).to be_a(String)
        expect(warning).to include('cflinuxfs3')
        expect(warning).to include('deprecated')
        expect(warning).to include('End of life December 2025')
      end

      it 'includes stack name when description is empty' do
        stack.description = ''
        warning = StackStateValidator.build_deprecation_warning(stack)
        expect(warning).to include('cflinuxfs3')
      end

      it 'handles nil description' do
        stack.description = nil
        warning = StackStateValidator.build_deprecation_warning(stack)
        expect(warning).to include('cflinuxfs3')
      end
    end

    describe 'state behavior matrix' do
      let(:active_stack) { Stack.make(state: StackStates::STACK_ACTIVE) }
      let(:deprecated_stack) { Stack.make(state: StackStates::STACK_DEPRECATED) }
      let(:restricted_stack) { Stack.make(state: StackStates::STACK_RESTRICTED) }
      let(:disabled_stack) { Stack.make(state: StackStates::STACK_DISABLED) }

      describe 'new app creation' do
        it 'allows ACTIVE without warnings' do
          result = StackStateValidator.validate_for_new_app!(active_stack)
          expect(result).to be_empty
        end

        it 'allows DEPRECATED with warnings' do
          result = StackStateValidator.validate_for_new_app!(deprecated_stack)
          expect(result).not_to be_empty
        end

        it 'rejects RESTRICTED' do
          expect { StackStateValidator.validate_for_new_app!(restricted_stack) }.to raise_error(StackStateValidator::RestrictedStackError)
        end

        it 'rejects DISABLED' do
          expect { StackStateValidator.validate_for_new_app!(disabled_stack) }.to raise_error(StackStateValidator::DisabledStackError)
        end
      end

      describe 'restaging' do
        it 'allows ACTIVE without warnings' do
          result = StackStateValidator.validate_for_restaging!(active_stack)
          expect(result).to be_empty
        end

        it 'allows DEPRECATED with warnings' do
          result = StackStateValidator.validate_for_restaging!(deprecated_stack)
          expect(result).not_to be_empty
        end

        it 'allows RESTRICTED without warnings' do
          result = StackStateValidator.validate_for_restaging!(restricted_stack)
          expect(result).to be_empty
        end

        it 'rejects DISABLED' do
          expect { StackStateValidator.validate_for_restaging!(disabled_stack) }.to raise_error(StackStateValidator::DisabledStackError)
        end
      end
    end
  end
end

require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Stack, type: :model do
    let(:file) { File.join(Paths::FIXTURES, 'config/stacks.yml') }

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it 'has apps' do
        stack = Stack.make
        process1 = ProcessModelFactory.make(stack:)
        process2 = ProcessModelFactory.make(stack:)
        expect(stack.apps).to contain_exactly(process1, process2)
      end

      it 'does not associate non-web v2 apps' do
        stack = Stack.make
        process1 = ProcessModelFactory.make(type: 'web', stack: stack)
        ProcessModelFactory.make(type: 'other', stack: stack)
        expect(stack.apps).to contain_exactly(process1)
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_uniqueness :name }
      it { is_expected.to strip_whitespace :name }

      describe 'state validation' do
        it 'accepts valid states' do
          stack = Stack.make
          Stack::VALID_STATES.each do |valid_state|
            stack.state = valid_state
            expect(stack).to be_valid
          end
        end

        it 'rejects invalid states' do
          stack = Stack.make
          stack.state = 'INVALID'
          expect(stack).not_to be_valid
          expect(stack.errors[:state]).to include(:includes)
        end

        it 'allows nil state' do
          stack = Stack.make
          stack.state = nil
          expect(stack).to be_valid
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :description, :build_rootfs_image, :run_rootfs_image }
      it { is_expected.to import_attributes :name, :description, :build_rootfs_image, :run_rootfs_image}
    end

    describe '.configure' do
      context 'with valid config' do
        it 'can load' do
          Stack.configure(file)
        end
      end

      context 'with invalid config' do
        let(:file) { File.join(Paths::FIXTURES, 'config/invalid_stacks.yml') }

        {
          default: 'default => Missing key',
          stacks: 'name => Missing key',
          deprecated_stacks: 'deprecated_stacks => Expected instance of Array, given instance of Hash }'
        }.each do |key, expected_error|
          it "requires #{key} (validates via '#{expected_error}')" do
            expect do
              Stack.configure(file)
            end.to raise_error(Membrane::SchemaValidationError, /#{expected_error}/)
          end
        end
      end
    end

    describe '.populate' do
      context 'when config was not set' do
        before { Stack.configure(nil) }

        it 'raises config not specified error' do
          expect do
            Stack.default
          end.to raise_error(Stack::MissingConfigFileError)
        end
      end

      context 'when config was set' do
        before { Stack.configure(file) }

        context 'when there are no stacks in the database' do
          before { Stack.dataset.destroy }

          it 'creates them all' do
            Stack.populate

            cider = Stack.find(name: 'cider')
            expect(cider.description).to eq('cider-description')

            default_stack = Stack.find(name: 'default-stack-name')
            expect(default_stack.description).to eq('default-stack-description')
          end

          describe 'build and run rootfs image names' do
            context 'when the build or run rootfs image names are blank' do
              it 'uses the stack name instead' do
                Stack.populate
                cflinuxfs4 = Stack.find(name: 'cflinuxfs4')
                expect(cflinuxfs4.build_rootfs_image).to eq 'cflinuxfs4'
                expect(cflinuxfs4.run_rootfs_image).to eq 'cflinuxfs4'
              end
            end

            context 'when the build or run rootfs image names are provided' do
              it 'sets the field values' do
                Stack.configure(File.join(Paths::FIXTURES, 'config/stacks_include_build_run.yml'))
                Stack.populate

                separate_images = Stack.find(name: 'separate-build-run-images')
                expect(separate_images.build_rootfs_image).to eq 'build'
                expect(separate_images.run_rootfs_image).to eq 'run'
              end
            end

            context 'when an existing stack would have its rootfs images changed' do
              before do
                Stack.configure(file)
                Stack.populate
              end

              it 'warns and does not update' do
                Stack.configure(File.join(Paths::FIXTURES, 'config/stacks_include_build_run.yml'))

                mock_logger = double
                allow(Steno).to receive(:logger).and_return(mock_logger)

                expect(mock_logger).to receive(:warn).with(
                  'stack.populate.collision',
                  {
                    'name' => 'cider',
                    'description' => 'cider-description',
                    'build_rootfs_image' => 'cider-build',
                    'run_rootfs_image' => 'cider-run'
                  }
                )

                Stack.populate

                cider = Stack.find(name: 'cider')
                expect(cider.build_rootfs_image).to eq 'cider'
                expect(cider.run_rootfs_image).to eq 'cider'
              end
            end
          end

          context 'when there are existing stacks in the database' do
            before do
              Stack.dataset.destroy
              Stack.populate
            end

            it 'does not create duplicates' do
              expect { Stack.populate }.not_to(change(Stack, :count))
            end

            context 'and the config file would change an existing stack' do
              it 'warns and not update' do
                cider = Stack.find(name: 'cider')
                cider.description = 'cider-description has changed'
                cider.save

                mock_logger = double
                allow(Steno).to receive(:logger).and_return(mock_logger)

                expect(mock_logger).to receive(:warn).with('stack.populate.collision', { 'name' => 'cider', 'description' => 'cider-description' })

                Stack.populate

                second_lookup = Stack.find(name: 'cider')
                expect(second_lookup.description).to eq('cider-description has changed')
              end
            end
          end
        end
      end
    end

    describe '.default' do
      before { Stack.configure(file) }

      context 'when config was not set' do
        before { Stack.configure(nil) }

        it 'raises config not specified error' do
          expect do
            Stack.default
          end.to raise_error(Stack::MissingConfigFileError)
        end
      end

      context 'when config was set' do
        before { Stack.dataset.destroy }

        context 'when stack is found with default name' do
          before { Stack.make(name: 'default-stack-name') }

          it 'returns found stack' do
            expect(Stack.default.name).to eq('default-stack-name')
          end
        end

        context 'when stack is not found with default name' do
          it 'raises MissingDefaultStack' do
            expect do
              Stack.default
            end.to raise_error(Stack::MissingDefaultStackError, /default-stack-name/)
          end
        end
      end
    end

    describe '#default?' do
      before { Stack.configure(file) }

      let(:stack) { Stack.make(name:) }
      let(:name) { 'mimi' }

      context 'when config was not set' do
        before { Stack.configure(nil) }

        it 'raises config not specified error' do
          expect do
            stack.default?
          end.to raise_error(Stack::MissingConfigFileError)
        end
      end

      context 'when config was set' do
        before { Stack.dataset.destroy }

        context 'when the stack has the default name' do
          let(:name) { 'default-stack-name' }

          it 'returns true' do
            expect(stack.default?).to be true
          end
        end

        context 'when there is NO default stack' do
          it 'returns false' do
            expect(stack.default?).to be false
          end
        end

        context 'when stack does NOT have the default name' do
          before { Stack.make(name: 'default-stack-name') }

          it 'returns false' do
            expect(stack.default?).to be false
          end
        end
      end
    end

    describe '#destroy' do
      let(:stack) { Stack.make }

      it 'succeeds if there are no apps' do
        expect { stack.destroy }.not_to raise_error
      end

      it 'fails if there are apps' do
        ProcessModelFactory.make(stack:)
        expect { stack.destroy }.to raise_error Stack::AppsStillPresentError
      end
    end
  end
end

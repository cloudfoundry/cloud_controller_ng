require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe BuildpackInstallerFactory do
      describe '#plan' do
        let(:name) { 'the-buildpack' }
        let(:file) { 'the-file' }
        let(:opts) { { enabled: true, locked: false, position: 1 } }
        let(:factory) { BuildpackInstallerFactory.new }
        let(:jobs) { factory.plan(name, buildpack_fields) }

        before do
          allow(Buildpacks::StackNameExtractor).to receive(:extract_from_file)
        end

        context 'when the manifest has one buildpack' do
          let(:buildpack_fields) { [{ file: file, options: opts }] }
          let(:single_buildpack_job) { jobs.first }

          shared_examples_for 'passthrough parameters' do
            it 'passes through buildpack name' do
              expect(single_buildpack_job.name).to eq(name)
            end
            it 'passes through opts' do
              expect(single_buildpack_job.options).to eq(opts)
            end
            it 'passes through file' do
              expect(single_buildpack_job.file).to eq(file)
            end
          end

          context 'when there is no matching buildpack record by name' do
            context 'and there is a detected stack in the zipfile' do
              let(:buildpack_fields) { [{ file: file, options: opts, stack: 'detected stack' }] }

              include_examples 'passthrough parameters'

              it 'plans to create the record' do
                expect(single_buildpack_job).to be_a(CreateBuildpackInstaller)
              end

              it 'sets the stack to the detected stack' do
                expect(single_buildpack_job.stack_name).to eq('detected stack')
              end
            end

            context 'and there is not a detected stack in the zipfile' do
              include_examples 'passthrough parameters'

              it 'plans to create the record' do
                expect(single_buildpack_job).to be_a(CreateBuildpackInstaller)
              end

              it 'sets the stack to nil' do
                expect(single_buildpack_job.stack_name).to eq(nil)
              end
            end
          end

          context 'and when there is a single existing buildpack that matches by name' do
            context 'and when that buildpack record has a stack' do
              let(:existing_stack) { Stack.make(name: 'existing stack') }
              let!(:existing_buildpack) { Buildpack.make(name: name, stack: existing_stack.name, key: 'new_key', guid: 'the-guid') }

              context 'and the buildpack zip has the same stack' do
                let(:buildpack_fields) { [{ file: file, options: opts, stack: existing_stack.name }] }

                include_examples 'passthrough parameters'

                it 'sets the stack to the matching stack' do
                  expect(single_buildpack_job.stack_name).to eq(existing_stack.name)
                end

                it 'plans on updating that record' do
                  expect(single_buildpack_job).to be_a(UpdateBuildpackInstaller)
                end

                it 'identifies the buildpack record to update' do
                  expect(single_buildpack_job.guid_to_upgrade).to eq(existing_buildpack.guid)
                end
              end

              context 'and the buildpack zip has a different stack' do
                let(:buildpack_fields) { [{ file: file, options: opts, stack: 'manifest stack' }] }

                include_examples 'passthrough parameters'

                it 'it plans on creating a new record' do
                  expect(single_buildpack_job).to be_a(CreateBuildpackInstaller)
                end

                it 'gives the record to the detected stack' do
                  expect(single_buildpack_job.stack_name).to eq 'manifest stack'
                end
              end

              context 'and the manifest stack is nil' do
                let(:buildpack_fields) { [{ file: file, options: opts, stack: nil }] }

                it 'errors' do
                  expect {
                    factory.plan(name, buildpack_fields)
                  }.to raise_error(BuildpackInstallerFactory::StacklessBuildpackIncompatibilityError)
                end
              end
            end

            context 'and that buildpack record has a nil stack' do
              let!(:existing_buildpack) { Buildpack.make(name: name, stack: nil, key: 'new_key', guid: 'the-guid') }

              context 'and the buildpack zip also has a nil stack' do
                let(:buildpack_fields) { [{ file: file, options: opts, stack: nil }] }

                include_examples 'passthrough parameters'

                it 'plans to update' do
                  expect(single_buildpack_job).to be_a(UpdateBuildpackInstaller)
                end

                it 'identifies the buildpack record to update' do
                  expect(single_buildpack_job.guid_to_upgrade).to eq(existing_buildpack.guid)
                end

                it 'leaves the stack nil' do
                  expect(single_buildpack_job.stack_name).to be nil
                end
              end

              context 'but the buildpack zip /has/ a stack' do
                let(:buildpack_fields) { [{ file: file, options: opts, stack: 'manifest stack' }] }

                include_examples 'passthrough parameters'

                it 'plans on updating it' do
                  expect(single_buildpack_job).to be_a(UpdateBuildpackInstaller)
                end

                it 'gives the record to the detected stack' do
                  expect(single_buildpack_job.stack_name).to eq 'manifest stack'
                end

                it 'identifies the buildpack record to update' do
                  expect(single_buildpack_job.guid_to_upgrade).to eq(existing_buildpack.guid)
                end
              end
            end
          end

          context 'and when there are many existing buildpacks' do
            let(:existing_stack) { Stack.make(name: 'existing stack') }
            let!(:existing_buildpack) { Buildpack.make(name: name, stack: existing_stack.name, key: 'new_key', guid: 'the-guid') }

            let(:another_existing_stack) { Stack.make(name: 'another existing stack') }
            let!(:another_existing_buildpack) { Buildpack.make(name: name, stack: another_existing_stack.name, key: 'new_key', guid: 'another-guid') }

            context 'and one matches the manifest stack' do
              let(:buildpack_fields) { [{ file: file, options: opts, stack: existing_stack.name }] }

              include_examples 'passthrough parameters'

              it 'sets the stack to the matching stack' do
                expect(single_buildpack_job.stack_name).to eq(existing_stack.name)
              end

              it 'plans on updating that record' do
                expect(single_buildpack_job).to be_a(UpdateBuildpackInstaller)
              end

              it 'identifies the buildpack record to update' do
                expect(single_buildpack_job.guid_to_upgrade).to eq(existing_buildpack.guid)
              end
            end

            context 'and the manifest stack is nil' do
              let(:buildpack_fields) { [{ file: file, options: opts, stack: nil }] }

              it 'errors' do
                expect {
                  factory.plan(name, buildpack_fields)
                }.to raise_error(BuildpackInstallerFactory::StacklessBuildpackIncompatibilityError)
              end
            end

            context 'and none match the manifest stack' do
              let(:buildpack_fields) { [{ file: file, options: opts, stack: 'manifest stack' }] }

              include_examples 'passthrough parameters'

              it 'it plans on creating a new record' do
                expect(single_buildpack_job).to be_a(CreateBuildpackInstaller)
              end

              it 'gives the record to the detected stack' do
                expect(single_buildpack_job.stack_name).to eq 'manifest stack'
              end
            end
          end
        end

        context 'when the manifest has multiple buildpack entries for one name, with different stacks' do
          let(:another_file) { 'the-other-file' }
          let(:buildpack_fields) { [{ file: file, options: opts, stack: 'existing stack' }, { file: another_file, options: opts, stack: 'manifest stack' }] }

          context 'and there are no matching Buildpacks' do
            it 'plans to create all the Buildpacks' do
              expect(jobs.length).to eq(2)
              expect(jobs[0]).to be_a(CreateBuildpackInstaller)
              expect(jobs[0].stack_name).to eq('existing stack')
              expect(jobs[1]).to be_a(CreateBuildpackInstaller)
              expect(jobs[1].stack_name).to eq('manifest stack')
            end
          end

          context 'and there is only one matching Buildpack' do
            let!(:existing_buildpack) { Buildpack.make(name: name, stack: nil, key: 'new_key', guid: 'the-guid') }
            context 'and the Buildpack has a nil stack' do
              context 'and the buildpack is not locked' do
                it 'creates a job for each buildpack' do
                  expect(jobs.length).to eq(2)
                end

                it 'updates the Buildpack stack' do
                  expect(jobs[0]).to be_a(UpdateBuildpackInstaller)
                  expect(jobs[0].stack_name).to eq('existing stack')
                  expect(jobs[0].guid_to_upgrade).to eq(existing_buildpack.guid)
                end

                it 'creates new Buildpacks for the remaining manifest entries' do
                  expect(jobs[1]).to be_a(CreateBuildpackInstaller)
                  expect(jobs[1].stack_name).to eq('manifest stack')
                end
              end

              context 'and the buildpack is locked' do
                let!(:existing_buildpack) { Buildpack.make(name: name, stack: nil, key: 'new_key', guid: 'the-guid', locked: true) }

                it 'raises' do
                  msg = "Attempt to install '#{name}' for multiple stacks failed. Buildpack '#{name}' cannot be locked during upgrade."
                  expect { factory.plan(name, buildpack_fields) }.to raise_error(
                    BuildpackInstallerFactory::LockedStacklessBuildpackUpgradeError, msg)
                end
              end
            end

            context 'and the Buildpack has a non-nil stack' do
              let(:existing_stack) { Stack.make(name: 'existing stack') }
              let!(:existing_buildpack) { Buildpack.make(name: name, stack: existing_stack.name, key: 'new_key', guid: 'the-guid') }

              it 'creates a job for each buildpack' do
                expect(jobs.length).to eq(2)
              end

              it 'updates the Buildpack which has a matching stack in the manifest entry' do
                expect(jobs[0]).to be_a(UpdateBuildpackInstaller)
                expect(jobs[0].stack_name).to eq(existing_stack.name)
                expect(jobs[0].guid_to_upgrade).to eq(existing_buildpack.guid)
              end
              it 'creates new Buildpacks for the remaining manifest entries' do
                expect(jobs[1]).to be_a(CreateBuildpackInstaller)
                expect(jobs[1].stack_name).to eq('manifest stack')
              end
            end
          end

          context 'and there are multiple matching Buildpacks' do
            let(:existing_stack) { Stack.make(name: 'existing stack') }
            let!(:existing_buildpack) { Buildpack.make(name: name, stack: existing_stack.name, key:
              'new_key', guid: 'the-guid')
            }

            let(:another_existing_stack) { Stack.make(name: 'another existing stack') }
            let!(:another_existing_buildpack) { Buildpack.make(name: name, stack: another_existing_stack.name, key: 'a_different_key', guid: 'a-different-guid') }
            let(:buildpack_fields) { [{ file: file, options: opts, stack: existing_stack.name }, { file: another_file, options: opts, stack: another_existing_stack.name }] }

            context 'and none of them has a nil stack' do
              it 'creates a job for each buildpack' do
                expect(jobs.length).to eq(2)
              end

              it 'updates the Buildpacks which have matching stacks in their manifest entry' do
                expect(jobs[0]).to be_a(UpdateBuildpackInstaller)
                expect(jobs[0].stack_name).to eq(existing_stack.name)
                expect(jobs[0].guid_to_upgrade).to eq(existing_buildpack.guid)

                expect(jobs[1]).to be_a(UpdateBuildpackInstaller)
                expect(jobs[1].stack_name).to eq(another_existing_stack.name)
                expect(jobs[1].guid_to_upgrade).to eq(another_existing_buildpack.guid)
              end
            end
          end

          context 'when one of them is stackless' do
            let(:buildpack_fields) { [{ file: file, options: opts }] }

            before do
              Stack.make(name: 'existing stack')
              Buildpack.make(name: name, stack: 'existing stack')
              Buildpack.make(name: name, stack: nil)
            end

            it 'raises' do
              msg = "Attempt to install '#{name}' failed. Ensure that all buildpacks have a stack associated with them before upgrading."
              expect { factory.plan(name, buildpack_fields) }.to raise_error(
                BuildpackInstallerFactory::StacklessAndStackfulMatchingBuildpacksExistError, msg)
            end
          end
        end

        context 'when the manifest has multiple buildpack entries for one name, with the same stack' do
          let(:another_file) { 'the-other-file' }
          let(:buildpack_fields) { [{ file: file, options: opts, stack: 'stack' }, { file: another_file, options: opts, stack: 'stack' }] }

          it 'raises a DuplicateInstall error' do
            expect {
              factory.plan(name, buildpack_fields)
            }.to raise_error(BuildpackInstallerFactory::DuplicateInstallError)
          end
        end

        context 'when the manifest has multiple buildpack entries for one name, neither specifying a stack' do
          let(:another_file) { 'the-other-file' }
          let(:buildpack_fields) { [{ file: file, options: opts, stack: nil }, { file: another_file, options: opts, stack: nil }] }

          it 'raises a DuplicateInstall error' do
            expect {
              factory.plan(name, buildpack_fields)
            }.to raise_error(BuildpackInstallerFactory::DuplicateInstallError)
          end
        end

        context 'when the manifest has multiple buildpack entries for one name, one stackful and one stackless' do
          let(:another_file) { 'the-other-file' }
          let(:buildpack_fields) { [{ file: file, options: opts, stack: 'stack' }, { file: another_file, options: opts, stack: nil }] }

          it 'raises a StacklessBuildpackIncompatibilityError error' do
            expect {
              factory.plan(name, buildpack_fields)
            }.to raise_error(BuildpackInstallerFactory::StacklessBuildpackIncompatibilityError)
          end
        end
      end
    end
  end
end

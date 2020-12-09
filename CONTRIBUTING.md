# Contributing to Cloud Controller

The Cloud Controller team uses GitHub and accepts contributions via
[pull request](https://help.github.com/articles/using-pull-requests).

See the [wiki](https://github.com/cloudfoundry/cloud_controller_ng/wiki) for design notes and other helpful information.

## Contributor License Agreement

Follow these steps to make a contribution to any of our open source repositories:

1. Ensure that you have completed our CLA Agreement for
  [individuals](https://www.cloudfoundry.org/pdfs/CFF_Individual_CLA.pdf) or
  [corporations](https://www.cloudfoundry.org/pdfs/CFF_Corporate_CLA.pdf).

1. Set your name and email (these should match the information on your submitted CLA)

        git config --global user.name "Firstname Lastname"
        git config --global user.email "your_email@example.com"

1. All contributions must be sent using GitHub pull requests as they create a nice audit trail and structured approach.
   The originating github user has to either have a github id on-file with the list of approved users that have signed the CLA or they can be a public "member" of a GitHub organization for a group that has signed the corporate CLA. This enables the corporations to manage their users themselves instead of having to tell us when someone joins/leaves an organization. By removing a user from an organization's GitHub account, their new contributions are no longer approved because they are no longer covered under a CLA.

   If a contribution is deemed to be covered by an existing CLA, then it is analyzed for engineering quality and product fit before merging it.

   If a contribution is not covered by the CLA, then the automated CLA system notifies the submitter politely that we cannot identify their CLA and ask them to sign either an individual or corporate CLA. This happens automatically as a comment on pull requests.

   When the project receives a new CLA, it is recorded in the project records, the CLA is added to the database for the automated system uses, then we manually make the Pull Request as having a CLA on-file.

## Contribution Workflow

1. Fork the repository
1. Check out `main` of cloud_controller
1. Create a feature branch (`git checkout -b better_cloud_controller`)
1. Make changes on your branch
1. [Run unit tests](https://github.com/cloudfoundry/cloud_controller_ng#unit-tests)
1. [Run static analysis](https://github.com/cloudfoundry/cloud_controller_ng#running-static-analysis)
1. Push to your fork (`git push origin better_cloud_controller`)
1. Deploy to a bosh environment (see guide below for how to deploy to a local bosh-lite)
1. [Run CF Acceptance Tests](https://github.com/cloudfoundry/cloud_controller_ng#cf-acceptance-tests-cats)
1. Submit your PR

### Deploying your changes to a bosh-lite
1. Deploy a bosh director (one easy option is deploying a [bosh-lite](https://bosh.io/docs/bosh-lite/) on your development machine using [bosh deployment](https://github.com/cloudfoundry/bosh-deployment))
1. Check out the `main` branch of [cf-deployment](https://github.com/cloudfoundry/cf-deployment)
1. Check out the `main` branch of [capi-release](https://github.com/cloudfoundry/capi-release)
1. Run `scripts/update` from the `capi-release` repo to update submodules
1. Checkout your branch of cloud_controller_ng in the submodule of capi-release.
1. Run this [script](https://github.com/cloudfoundry/capi-workspace/blob/main/scripts/create_and_upload) to create and upload a capi dev release to your bosh-lite.
1. Run this [script](https://github.com/cloudfoundry/capi-workspace/blob/main/scripts/deploy) to deploy CF to your bosh-lite with the capi dev release you just created.

### PR Considerations
We favor pull requests with very small, single commits with a single purpose.

Your pull request is much more likely to be accepted if:

* Your pull request includes tests

* Your pull request is small and focused. As a rule of thumb, PRs with > 400 changed lines are difficult for us to review critically. We are happy to work with you to break up larger PRs into more manageable chunks.

* Your pull request has a clear message that conveys the intent of your change


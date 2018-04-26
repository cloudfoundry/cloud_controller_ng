# Contributing to Cloud Controller

The Cloud Foundry team uses GitHub and accepts contributions via
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

## General Workflow

1. Fork the repository
1. Check out `master` of cloud_controller 
1. Create a feature branch (`git checkout -b better_cloud_controller`)
1. Make changes on your branch
1. [Run unit tests](https://github.com/cloudfoundry/cloud_controller_ng#unit-tests)
1. [Run static analysis](https://github.com/cloudfoundry/cloud_controller_ng#running-static-analysis)
1. If you are deploying to bosh, checkout `develop` of [capi-release](https://github.com/cloudfoundry/capi-release)
1. [Run CF Acceptance Tests](https://github.com/cloudfoundry/cloud_controller_ng#cf-acceptance-tests-cats)
1. Push to your fork (`git push origin better_cloud_controller`) and submit a pull request

We favor pull requests with very small, single commits with a single purpose.

Your pull request is much more likely to be accepted if:

* Your pull request includes tests

* Your pull request is small and focused with a clear message that conveys the intent of your change

## PR size

Whenever possible, please try to PR small, atomic units of work. As a rule of thumb, PRs with > 400 changed lines are difficult for us to review critically. We are happy to work with you to break up larger PRs into more managable chunks.

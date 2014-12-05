# README for CF CC Localization

__The Cloud Foundry Cloud-Controller is planning to be translated to one of the supported languages. See "How you can contribute" to help in this effort.__

The CloudFoundry (CF) Cloud-Controller (CC) is now being internationalized (i18n).

This README details what features are available, what are not, how you can contribute, when, as well as the overarching goals we had in mind as we entered this update of CC.

## What?

There are a lot of REST APIs defined in the Cloud Controller project, which are used by end user or further program. The responses of the REST APIs contain many human read messages which can be translated.

At the time of writing this, we are trying to internationalize the error messages of CC REST APIs, so this is where the CF CC localization actually takes place.

## When?

The CF CC i18n work is still undergoing, the main i18n framework in CC is submitted as a PR and the following controllers' i18n enablement is still under development. After all the work and PRs has been finished from CC side, this readme file will be updated and all the translations in 'Errors' project will be effective then.

At the mean time, developers can help to translate the error messages into different language first. We have listed all the language and translation information in the 'Goals' section. Please refer to the information there and contribute your translations.

## How can you contribute?

__Submit pull requests for languages files with translations/improvements.__ If you see typos, grammar errors,  ambiguous strings or lingering English then please find the appropriate string in the `errors/i18n/*_v2.yml` and submit a PR with the fix(es). (You can also report this as an issue in Github, but if you do understand the language, we would really appreciate the fix.)

## Goals

Our goal is to have translations for the following languages first:

| Language              | Locale | Status                  |
|-----------------------|--------|-------------------------|
| English               | en_US  | In progress             |
| Chinese (simplified)  | zh_CN  | In progress             |
| French                | fr_FR  |                         |
| Spanish               | es_ES  |                         |
| German                | de_DE  |                         |
| Italian               | it_IT  |                         |
| Japanese              | ja_JA  |                         |
| Korean                | ko_KO  |                         |
| Portuguese (Brazil)   | pt_BR  |                         |
| Chinese (traditional) | zh_HK  |                         |
| Russian               | ru_RU  |                         |

If you are interested in submitting translations for another language/locale, then please communicate with us via VCAP-DEV mailing list first.

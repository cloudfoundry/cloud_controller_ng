# Upgrade Guide

This document is intended to help client authors upgrade from Cloud Foundry's V2 API to the V3 API.

When moving to the V3 API, it is important to understand that the V3 API is backed by the same database as the V2 API. Though resources may be presented differently and have different interaction patterns, the internal state of CF is the same across both APIs. If you create an organization using the V3 API,
it will be visible to the V2 API, and vice-versa.

If you have questions, need help, or want to chat about the upgrade process, please reach out to us in [Cloud Foundry Slack](https://cloudfoundry.slack.com/messages/C07C04W4Q).



## v0.6.7
- Fix: Change names of controllers to be less likely to conflict with host app inflections
- Added: Pusher now pushes asychronously via Sidekiq using the Pusher batch API

## v0.6.6
- Fix: don't run the schema change detection and cache rebuild inside rake tasks or migrations

## v0.6.5
- Added `reset!` and `reset!(hard: true)` methods to `Subscription`. Reset will load the IDs that should be part of the subscription from the database, and ensure that the graph matches those. It then re-broadcasts the payloads to all connected clients. Hard reset will do the same, but also clear all cached IDs and subscription hooks on instances - this is equivalent from starting from scratch.
- Added `enforce: boolean` option to GraphHelper
- When subscriptions are re-activated they now set the IDs with `enforce: true`, as there could be conditions where updates that were made while a subscription was not active would not be properly registered.
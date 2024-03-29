## v0.8.6
- Fix config usage, to allow changing websocket provider

## v0.8.4
- Fix implicit kwargs that fail in Ruby 3+

## v0.8.3
- Fix lock bug on checking dupe schema

## v0.8.2
- Don't rebuild cache during schema change detection - just wipe it and let cold cache handling work as intended

## v0.8.1
- Allow setting the Sidekiq queue name for Jason payloads

## v0.8.0
- Cold cache handling:
 - Expiry is now set on all cached models of one week
 - Code now handles case where cached model is missing and repopulates the cache

## v0.7.5
- Fixed JS errors when payloads arrive on websockets after the subscription has been unmounted
- Fixed errors during initialization due to calling `cache_all` on a Rails model before it had fully initialized.

## v0.7.3
- Added: Add JasonContext to exports, for use in scenarios where you need to forward the context into some other React reconciler (e.g. `react-three-fiber`)
- Fixed: Unneeded `reload` in Publisher resulting in extra database calls

## v0.7.1
- Added: Authorization for REST endpoints. Previously these just inherited logic from ApplicationController. Pass a `update_authorization_service` option to the Jason initializer to use this.

## v0.7.0
- Added: New forms of conditional subscription. You can now add conditions on fields other than the primary key.
E.g.
```
useSub({ model: 'post', conditions: { created_at: { type: 'between' value: ['2020-01-01', '2020-02-01'] } })
useSub({ model: 'post', conditions: { hidden: false } })
```

- Added: Consistency checker. You can run `Jason::ConsistencyChecker.check_all` to validate all current subscriptions against the contents of the database. If you call `check_all(fix: true)` it will called `reset!(hard: true)` on any subscription whose contents do not match the database.

- Changed: Subscriptions no longer get cleared when consumer count drops to 0. This will be replaced in a future release with a reaping process to clean up inactive subscriptions.

- Changed: ActionCable subscriptions get their initial payload via REST instead of ActionCable, as this seems to deliver snappier results

- Fixed: Small bug in useEager that could throw error if relation wasn't present.

## v0.6.9
- Added: Optimistic updates now return a promise which can chained to perform actions _after_ an update is persisted to server. (For example, if your component depends on fetching additional data that only exists once your instance is persisted)
```
act.posts.add({ name: 'new post' })
  .then(loadEditPostModal)
  .catch(e => console.error("Oh no!", e))
```

## v0.6.8
- Fix: Objects in 'all' subscription not always being broadcast

## v0.6.7
- Fix: Change names of controllers to be less likely to conflict with host app inflections
- Added: Pusher now pushes asychronously via Sidekiq using the Pusher batch API

## v0.6.6
- Fix: don't run the schema change detection and cache rebuild inside rake tasks or migrations

## v0.6.5
- Added `reset!` and `reset!(hard: true)` methods to `Subscription`. Reset will load the IDs that should be part of the subscription from the database, and ensure that the graph matches those. It then re-broadcasts the payloads to all connected clients. Hard reset will do the same, but also clear all cached IDs and subscription hooks on instances - this is equivalent from starting from scratch.
- Added `enforce: boolean` option to GraphHelper
- When subscriptions are re-activated they now set the IDs with `enforce: true`, as there could be conditions where updates that were made while a subscription was not active would not be properly registered.

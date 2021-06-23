# Jason

Jason is still in an experimental phase with a rapidly changing API. It is being used in some production applications, however it is still in 0.x.x series versions, which means that any 0.x version bump could introduce breaking changes.

## The goal

We wanted:
 - Automatic updates to client state based on database state
 - Persistence to the database without many layers of passing parameters
 - Redux for awesome state management
 - Optimistic updates

We also wanted to avoid writing essentially the same code multiple times in different places to handle common CRUD-like operations. Combine Rails schema definition files, REST endpoints, Redux actions, stores, reducers, handlers for websocket payloads and the translations between them, and it adds up to tons of repetitive boilerplate. Every change to the data schema requires updates in five or six files. This inhibits refactoring and makes mistakes more likely.

Jason attempts to minimize this repitition by auto-generating API endpoints, redux stores and actions from a single schema definition. Further it adds listeners to ActiveRecord models allowing the redux store to be subscribed to updates from a model or set of models.

An alternative way of thinking about Jason is "what if we applied the Flux/Redux state update pattern to make the _database_ the store?".

## Installation

Add the gem and the NPM package

```ruby
gem 'jason-rails'
```

```bash
  yarn add @jamesr2323/jason
```

You will also need have peer dependencies of `redux`, `react-redux` and `@reduxjs/toolkit`.

### In Rails

Include the module `Jason::Publisher` in all models you want to publish via Jason.

Create a new initializer e.g. `jason.rb` which defines your schema

```ruby
Jason.setup do |config|
  config.schema = {
    post: {
      subscribed_fields: [:id, :name]
    },
    comment: {
      subscribed_fields: [:id]
    },
    user: {
      subscribed_fields: [:id]
    }
  }
end
```

Mount the Jason engine in `routes.rb`
```ruby
mount Jason::Engine => "/jason"
```

### In your frontend code

First you need to wrap your root component in a `JasonProvider`.

```jsx
import { JasonProvider } from '@jamesr2323/jason'

return <JasonProvider>
  <YourApp />
</JasonProvider>
```

This is a wrapper around `react-redux` Provider component. This accepts the following props (all optional):

- `reducers` - An object of reducers that will be included in `configureStore`. Make sure these do not conflict with the names of any of the models you are configuring for use with Jason
- `extraActions` - Extra actions you want to be available via the `useAct` hook. (See below)
This must be a function which returns an object which will be merged with the main Jason actions. The function will be passed a dispatch function, store, axios instance and the Jason actions. For example you can add actions for one of your custom slices:

```js
function extraActions(dispatch, store, restClient, act) {
  return {
    local: {
      upsert: payload => dis({ type: 'local/upsert', payload })
    }
  }
}
```

- `middleware` - Passed directly to `configureStore` with additional Jason middleware

## Usage
Jason provides three custom hooks to access functionality.

### useAct
This returns an object which allows you to access actions which both update models on the server, and perform an optimistic update to the Redux store.

Example
```jsx
import React, { useState } from 'react'
import { useAct } from '@jamesr2323/jason'

export default function PostCreator() {
  const act = useAct()
  const [name, setName] = useState('')

  function handleClick() {
    act.posts.add({ name })
  }

  return <div>
    <input value={name} onChange={e => setName(e.target.value)} />
    <button onClick={handleClick}>Add</button>
  </div>
}
```

### useSub
This subscribes your Redux store to a model or set of models. It will automatically unsubscribe when the component unmounts.

Example
```jsx
import React from 'react'
import { useSelector } from 'react-redux'
import { useSub } from '@jamesr2323/jason'
import _ from 'lodash'

export default function PostsList() {
  useSub({ model: 'post', includes: ['comments'] })
  const posts = useSelector(s => _.values(s.posts.entities))

  return <div>
    { posts.map(({ id, name }) => <div key={id}>{ name }</div>) }
  </div>
}
```

### useEager
Jason stores all the data in a normalized form - one redux slice per model. Often you might want to get nested data from several slices for use in components. The `useEager` hook provides an API for doing that. Under the hood it's just a wrapper around useSelector, which aims to mimic the behaviour of Rails eager loading.

Example
This will fetch the comment as well as the post and user linked to it.

```jsx
import React from 'react'
import { useSelector } from 'react-redux'
import { useEager } from '@jamesr2323/jason'
import _ from 'lodash'

export default function Comment({ id }) {
  const comment = useEager('comments', id, ['post', 'user'])

  return <div>
    <p>{ comment.body }</p>
    <p>Made on post { comment.post.name } by { comment.user.name }</p>
  </div>
}
```

## Authorization

By default all models can be subscribed to and updated without authentication or authorization. Probably you want to lock down access. At the moment Jason has no opinion on how to handle authorization, it simply forwards parameters to a service that you provide - so the implementation can be as simple or as complex as you need.

### Authorizing subscriptions
You can do this by providing an class to Jason in the initializer under the `subscription_authorization_service` key. This must be a class receiving a message `call` with the parameters `user`, `model`, `conditions`, `sub_models` and return true or false for whether the user is allowed to access a subscription with those parameters. You can decide the implementation details of this to be as simple or complex as your app requires.

### Authorizing updates
Similarly to authorizing subscriptions, you can do this by providing an class to Jason in the initializer under the `update_authorization_service` key. This must be a class receiving a message `call` with the parameters `user`, `model`, `action`, `instance`, `params`  and return true or false for whether the user is allowed to make this update.

See the specs for some examples of this.

## Roadmap

Development is primarily driven by the needs of projects we're using Jason in. In no particular order, being considered is:
- Better detection of when subscriptions drop, delete subscription
- Failure handling - rolling back local state in case of an error on the server
- Authorization - more thorough authorization integration, with utility functions for common authorizations. Allowing authorization of access to particular fields such as restricting the fields of a user that are publicly broadcast.
- Utilities for "Draft editing" - both storing client-side copies of model trees which can be committed or discarded, as well as persisting a shadow copy to the database (to allow resumable editing, or possibly collaborative editing features)
- Benchmark and migrate if necessary ConnectionPool::Wrapper vs ConnectionPool
- Assess using RedisGraph for the graph diffing functionality, to see if this would provide a performance boost
- Improve the Typescript definitions (ie remove the abundant `any` typing currently used)

## Publishing a new version
- Update `version.rb`
- Update CHANGELOG
- `gem build`
- `gem push`
- `npm version [major/minor/patch]`
- `npm publish`
- Push new version to Github

## License

The gem, npm package and source code in the git repository are available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).



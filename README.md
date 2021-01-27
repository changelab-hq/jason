# Jason

Jason is still in a highly experimental phase with a rapidly changing API. Production use not recommended - but please give it a try!

## The goal

I wanted:
 - Automatic updates to client state based on database state
 - Persistence to the database without many layers of passing parameters
 - Redux for awesome state management
 - Optimistic updates

I also wanted to avoid writing essentially the same code multiple times in different places to handle common CRUD-like operations. Combine Rails schema definition files, REST endpoints, Redux actions, stores, reducers, handlers for websocket payloads and the translations between them, and it adds up to tons of repetitive boilerplate. Every change to the data schema requires updates in five or six files. This inhibits refactoring and makes mistakes more likely.

Jason attempts to minimize this repitition by auto-generating API endpoints, redux stores and actions from a single schema definition. Further it adds listeners to ActiveRecord models allowing the redux store to be subscribed to updates from a model or set of models.

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

### In your frontend code

First you need to wrap your root component in a `JasonProvider`.

```
import { JasonProvider } from '@jamesr2323/jason'

return <JasonProvider>
  <YourApp />
</JasonProvider>
```

This is a wrapper around `react-redux` Provider component. This accepts the following props (all optional):

- `reducers` - An object of reducers that will be included in `configureStore`. Make sure these do not conflict with the names of any of the models you are configuring for use with Jason
- `extraActions` - Extra actions you want to be available via the `useAct` hook. (See below)
This must be a function which returns an object which will be merged with the main Jason actions. The function will be passed a dispatch function, store, axios instance and the Jason actions. For example you can add actions for one of your custom slices:
```
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
Jason provides two custom hooks to access functionality.

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
```
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


## Roadmap

Development is primarily driven by the needs of projects we're using Jason in. In no particular order, being considered is:
- Failure handling - rolling back local state in case of an error on the server
- Authorization - integrating with a library like Pundit to determine who can subscribe to given state updates and perform updates on models
- Utilities for "Draft editing" - both storing client-side copies of model trees which can be committed or discarded, as well as persisting a shadow copy to the database (to allow resumable editing, or possibly collaborative editing features)
- Integration with pub/sub-as-a-service tools, such as Pusher

## Development



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/jason. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/jason/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Jason project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/jason/blob/master/CODE_OF_CONDUCT.md).

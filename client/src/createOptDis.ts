import _ from 'lodash'
import pluralize from 'pluralize'
import { v4 as uuidv4 } from 'uuid'

function enrich(type, payload) {
  if (type.split('/')[1] === 'upsert' && !(type.split('/')[0] === 'session')) {
    if (!payload.id) {
      return { ...payload, id: uuidv4() }
    }
  }
  return payload
}

export default function createOptDis(schema, dispatch, restClient, serverActionQueue) {
  const plurals = _.keys(schema).map(k => pluralize(k))
  let inFlight = false

  function enqueueServerAction (action) {
    serverActionQueue.addItem(action)
  }

  function dispatchServerAction() {
    const action = serverActionQueue.getItem()
    if (!action) return

    inFlight = true
    restClient.post('/jason/api/action', action)
    .then(serverActionQueue.itemProcessed)
    .catch(e => {
      dispatch({ type: 'upsertLocalUi', data: { error: JSON.stringify(e) } })
      serverActionQueue.itemProcessed()
    })
  }

  setInterval(dispatchServerAction, 10)

  return function (action) {
    const { type, payload } = action
    const data = enrich(type, payload)

    dispatch({ type, payload: data })

    if (plurals.indexOf(type.split('/')[0]) > -1) {
      enqueueServerAction({ type, payload: data })
    }
  }
}
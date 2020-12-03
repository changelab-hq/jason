import actionFactory from './actionFactory'
import pluralize from 'pluralize'
import _ from 'lodash'
import { v4 as uuidv4 } from 'uuid'

function enrich(type, payload) {
  if (type.split('/')[1] === 'upsert' && !(type.split('/')[0] === 'session')) {
    if (!payload.id) {
      return { ...payload, id: uuidv4() }
    }
  }
  return payload
}

function makeOptDis(schema, dispatch, restClient) {
  const plurals = _.keys(schema).map(k => pluralize(k))

  return function (action) {
    const { type, payload } = action
    const data = enrich(type, payload)

    dispatch(action)

    if (plurals.indexOf(type.split('/')[0]) > -1) {
      return restClient.post('/jason/api/action', { type, payload: data } )
        .catch(e => {
          dispatch({ type: 'upsertLocalUi', data: { error: JSON.stringify(e) } })
        })
    }
  }
}

function createActions(schema, store, restClient, extraActions) {
  const dis = store.dispatch;
  const optDis = makeOptDis(schema, dis, restClient)

  const actions =  _.fromPairs(_.map(schema, (config, model: string) => {
    if (config.priorityScope) {
      return [pluralize(model), actionFactory(optDis, store, model, { hasPriority: true })]
    } else {
      return [pluralize(model), actionFactory(optDis, store, model)]
    }
  }))

  const extraActionsResolved = extraActions(optDis, store, restClient)

  return _.merge(actions, extraActionsResolved)
}

export default createActions

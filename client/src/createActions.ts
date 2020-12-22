import actionFactory from './actionFactory'
import pluralize from 'pluralize'
import _ from 'lodash'

function createActions(schema, store, restClient, optDis, extraActions) {
  const actions =  _.fromPairs(_.map(schema, (config, model: string) => {
    if (config.priorityScope) {
      return [pluralize(model), actionFactory(optDis, store, model, { hasPriority: true })]
    } else {
      return [pluralize(model), actionFactory(optDis, store, model)]
    }
  }))

  const extraActionsResolved = extraActions ? extraActions(optDis, store, restClient, actions) : {}

  return _.merge(actions, extraActionsResolved)
}

export default createActions

import _ from 'lodash'
import pluralize from 'pluralize'

const pruneIdsMiddleware = schema => store => next => action => {
  const { type, payload } = action
  const result = next(action)

  const state = store.getState()
  if (type === 'jasonModels/setSubscriptionIds' || type === 'jasonModels/removeSubscriptionId') {
    const { model, ids } = payload

    let idsInSubs = []
    _.map(state.jasonModels[model], (subscribedIds, k) => {
      idsInSubs = _.union(idsInSubs, subscribedIds)
    })

    // Find IDs currently in Redux that aren't in any subscription
    const idsToRemove = _.difference(state[pluralize(model)].ids, idsInSubs)
    store.dispatch({ type: `${pluralize(model)}/removeMany`, payload: idsToRemove })
  }

  return result
}

export default pruneIdsMiddleware
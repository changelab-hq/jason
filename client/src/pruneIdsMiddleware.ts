import _ from 'lodash'
import pluralize from 'pluralize'

const pruneIdsMiddleware = schema => store => next => action => {
  const { type, payload } = action
  const result = next(action)
  const state = store.getState()
  if (type === 'jasonModels/setSubscriptionIds' || type === 'jasonModels/removeSubscriptionIds') {
    const { model } = payload

    let ids = []
    _.map(state.jasonModels[model], (subscribedIds, k) => {
      ids = _.union(ids, subscribedIds)
    })
    // Find IDs currently in Redux that aren't in any subscription
    const idsToRemove = _.difference(state[pluralize(model)].ids, ids)
    store.dispatch({ type: `${pluralize(model)}/removeMany`, payload: idsToRemove })
  }

  return result
}

export default pruneIdsMiddleware
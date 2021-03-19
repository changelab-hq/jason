import { createEntityAdapter, createSlice } from '@reduxjs/toolkit'
import pluralize from 'pluralize'
import _ from 'lodash'

function generateSlices(models) {
  // create two slices for each model. One to hold the persisted data, and one to hold draft data
  const sliceNames = models.map(k => pluralize(k)).concat(models.map(k => `${pluralize(k)}Drafts`))
  const adapter = createEntityAdapter()

  return _.fromPairs(_.map(sliceNames, name => {
    return [name, createSlice({
      name,
      initialState: adapter.getInitialState(),
      reducers: {
        upsert: adapter.upsertOne,
        upsertMany: adapter.upsertMany,
        add: adapter.addOne,
        setAll: adapter.setAll,
        remove: adapter.removeOne,
        removeMany: adapter.removeMany,
        movePriority: (s, { payload: { id, priority, parentFilter } }) => {
          // Get IDs and insert our item at the new index
          var affectedIds = _.orderBy(_.filter(_.values(s.entities), parentFilter).filter(e => e.id !== id), 'priority').map(e => e.id)
          affectedIds.splice(priority, 0, id)

          // Apply update
          affectedIds.forEach((id, i) => (s.entities[id] as any).priority = i)
        }
      }
    }).reducer]
  }))
}

function generateJasonSlices(models) {
  const initialState = _.fromPairs(_.map(models, (model_name) => {
    return [model_name, {}]
  }))

  const modelSliceReducer = createSlice({
    name: 'jasonModels',
    initialState,
    reducers: {
      setSubscriptionIds(s,a) {
        const { payload } = a
        const { subscriptionId, model, ids } = payload
        s[model][subscriptionId] = ids.map(id => String(id))
      },
      addSubscriptionId(s,a) {
        const { payload } = a
        const { subscriptionId, model, id } = payload
        s[model][subscriptionId] = _.union(s[model][subscriptionId] || [], [String(id)])
      },
      removeSubscriptionId(s,a) {
        const { payload } = a
        const { subscriptionId, model, id } = payload
        s[model][subscriptionId] = _.difference(s[model][subscriptionId] || [], [String(id)])
      },
      removeSubscription(s, a) {
        const { payload: { subscriptionId } } = a
        _.map(models, model => {
          delete s[model][subscriptionId]
        })
      }
    }
  }).reducer

  const jasonSliceReducer = createSlice({
    name: 'jason',
    initialState: {
      connected: false,
      queueSize: 0,
      error: null
    },
    reducers: {
      upsert: (s,a) => ({ ...s, ...a.payload })
    }
  }).reducer

  return { jason: jasonSliceReducer, jasonModels: modelSliceReducer }
}

export default function createJasonReducers(schema) {
  const models = _.keys(schema)

  return {
    ...generateSlices(models),
    ...generateJasonSlices(models)
  }
}

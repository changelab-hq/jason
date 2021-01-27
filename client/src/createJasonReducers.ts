import { createEntityAdapter, createSlice } from '@reduxjs/toolkit'
import pluralize from 'pluralize'
import _ from 'lodash'

function generateSlices(models) {
  const sliceNames = models.map(k => pluralize(k))
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
        s[model][subscriptionId] = ids
      },
      addSubscriptionId(s,a) {
        const { payload } = a
        const { subscriptionId, model, id } = payload
        s[model][subscriptionId] = _.union(s[model][subscriptionId] || [], [id])
      },
      removeSubscriptionId(s,a) {
        const { payload } = a
        const { subscriptionId, model, id } = payload
        s[model][subscriptionId] = _.remove(s[model][subscriptionId] || [], id)
      }
    }
  }).reducer

  const jasonSliceReducer = createSlice({
    name: 'jason',
    initialState: {
      connected: false,
      queueSize: 0
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

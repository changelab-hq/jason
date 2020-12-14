import { createEntityAdapter, createSlice } from '@reduxjs/toolkit'
import pluralize from 'pluralize'
import _ from 'lodash'

function generateSlices(schema) {
  const sliceNames = schema.map(k => pluralize(k))
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

export default function createJasonReducers(schema) {
  return generateSlices(_.keys(schema))
}

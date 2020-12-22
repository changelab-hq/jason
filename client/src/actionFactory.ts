import pluralize from 'pluralize'
import _ from 'lodash'
import { v4 as uuidv4 } from 'uuid'

export default (dis, store, entity, { extraActions = {}, hasPriority = false } = {}) => {
  function add(data = {}) {
    const id = uuidv4()
    return dis({ type: `${pluralize(entity)}/add`, payload: { id, ...data } })
  }

  function upsert(id, data) {
    return dis({ type: `${pluralize(entity)}/upsert`, payload: { id, ...data } })
  }

  function movePriority(id, priority, parentFilter = {}) {
    return dis({ type: `${pluralize(entity)}/movePriority`, payload: { id, priority, parentFilter } })
  }

  function setAll(data) {
    return dis({ type: `${pluralize(entity)}/setAll`, payload: data })
  }

  function remove(id) {
    return dis({ type: `${pluralize(entity)}/remove`, payload: id })
  }

  const extraActionsResolved = extraActions ? _.mapValues(extraActions, v => v(dis, store, entity)) : {}

  if (hasPriority) {
    return { add, upsert, setAll, remove, movePriority, ...extraActionsResolved }
  } else {
    return { add, upsert, setAll, remove, ...extraActionsResolved }
  }
}

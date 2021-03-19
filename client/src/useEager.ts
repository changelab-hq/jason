import _ from 'lodash'
import { useSelector } from 'react-redux'
import addRelations from './addRelations'

export default function useEager(entity, id = null, relations = []) {
  if (id) {
    return useSelector(s => addRelations(s, { ...s[entity].entities[String(id)] }, entity, relations), _.isEqual)
  } else {
    return useSelector(s => addRelations(s, _.values(s[entity].entities), entity, relations), _.isEqual)
  }
}


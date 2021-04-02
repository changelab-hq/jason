import _ from 'lodash'
import { useSelector } from 'react-redux'
import addRelations from './addRelations'

export default function useEager(entity: string, id = '', relations = [] as any) {
  if (id) {
    return useSelector(s => addRelations(s, { ...s[entity].entities[String(id)] }, entity, relations), _.isEqual)
  } else {
    return useSelector(s => addRelations(s, _.values(s[entity].entities), entity, relations), _.isEqual)
  }
}


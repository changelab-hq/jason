import _ from 'lodash'
import { useSelector } from 'react-redux'
import addRelations from './addRelations'

/* Can be called as
useDraft() => draft object for making updates
useDraft('entity', id) => returns [draft, object]
useDraft('entity', id, relations) => returns [draft, objectWithEmbeddedRelations]
*/

export default function useDraft(entity, id, relations = []) {
  // const entityDraft =`${entity}Draft`
  // const object = { ...s[entityDraft].entities[String(id)] }

  // return useSelector(s => addRelations(s, object, entity, relations, 'Draft'), _.isEqual)
}


import pluralize from 'pluralize'
import _ from 'lodash'

export default function addRelations(s, objects, objectType, relations, suffix = '') {
  // first find out relation name
  if (_.isArray(relations)) {
    relations.forEach(relation => {
      objects = addRelations(s, objects, objectType, relation)
    })
  } else if (typeof(relations) === 'object') {
    const relation = Object.keys(relations)[0]
    const subRelations = relations[relation]

    objects = addRelations(s, objects, objectType, relation)
    objects[relation] = addRelations(s, objects[relation], pluralize(relation), subRelations)
    // #
  } else if (typeof(relations) === 'string') {
    const relation = relations
    if (_.isArray(objects)) {
      objects = objects.map(obj => addRelations(s, obj, objectType, relation))
    } else if (_.isObject(objects)) {
      const relatedObjects = _.values(s[pluralize(relation) + suffix].entities)

      if(pluralize.isSingular(relation)) {
        objects = { ...objects, [relation]: _.find(relatedObjects, { id: objects[relation + 'Id'] }) }
      } else {
        objects = { ...objects, [relation]: relatedObjects.filter(e => e[pluralize.singular(objectType) + 'Id'] === objects.id) }
      }
    }
  }

  return objects
}
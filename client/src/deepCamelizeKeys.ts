import _ from 'lodash'

export default function deepCamelizeKeys(item, excludeIf = k => false) {
  function camelizeKey(key) {
    if (excludeIf(key)) return key
    return _.camelCase(key)
  }

  if (_.isArray(item)) {
    return _.map(item, item => deepCamelizeKeys(item, excludeIf))
  } else if (_.isObject(item)) {
    return _.mapValues(_.mapKeys(item, (v, k) => camelizeKey(k)), (v, k) => deepCamelizeKeys(v, excludeIf))
  } else {
    return item
  }
}


import axios from 'axios'
import applyCaseMiddleware from 'axios-case-converter'
import { validate as isUuid } from 'uuid'

const csrfToken = (document?.querySelector("meta[name=csrf-token]") as any)?.content
axios.defaults.headers.common['X-CSRF-Token'] = csrfToken

const restClient = applyCaseMiddleware(axios.create() as any, {
  preservedKeys: (key) => {
    return isUuid(key)
  }
}) as any

export default restClient
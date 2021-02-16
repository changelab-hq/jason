import { createContext } from 'react'
const eager = function(entity, id, relations) {
  console.error("Eager called but is not implemented")
}

const context = createContext({ actions: {} as any, subscribe: null, eager })

export default context

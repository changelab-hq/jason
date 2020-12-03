import { createContext } from 'react'

const context = createContext({ actions: {} as any, subscribe: null, eager: null })

export default context

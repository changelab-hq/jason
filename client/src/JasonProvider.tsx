import React from 'react'
import useJason from './useJason'
import { Provider } from 'react-redux'
import JasonContext from './JasonContext'

const JasonProvider = ({ reducers, middleware, extraActions, children }: { reducers?: any, middleware?: any, extraActions?: any, children?: React.FC }) => {
  const [store, value] = useJason({ reducers, middleware, extraActions })

  if(!(store && value)) return <div /> // Wait for async fetch of schema to complete

  return <Provider store={store}>
    <JasonContext.Provider value={value}>{ children }</JasonContext.Provider>
  </Provider>
}

export default JasonProvider



import createActions from './createActions'
import createJasonReducers from './createJasonReducers'
import createPayloadHandler from './createPayloadHandler'
import createOptDis from './createOptDis'
import createServerActionQueue from './createServerActionQueue'

import { createConsumer } from "@rails/actioncable"
import JasonContext from './JasonContext'
import axios from 'axios'
import applyCaseMiddleware from 'axios-case-converter'
import { Provider } from 'react-redux'
import { createEntityAdapter, createSlice, createReducer, configureStore } from '@reduxjs/toolkit'

import makeEager from './makeEager'
import { camelizeKeys } from 'humps'
import md5 from 'blueimp-md5'
import _ from 'lodash'
import React, { useState, useEffect } from 'react'
import { validate as isUuid } from 'uuid'

const JasonProvider = ({ reducers, middleware, extraActions, children }: { reducers?: any, middleware?: any, extraActions?: any, children?: React.FC }) => {
  const [store, setStore] = useState(null)
  const [value, setValue] = useState(null)
  const [connected, setConnected] = useState(false)

  const csrfToken = (document.querySelector("meta[name=csrf-token]") as any).content
  axios.defaults.headers.common['X-CSRF-Token'] = csrfToken
  const restClient = applyCaseMiddleware(axios.create() as any, {
    preservedKeys: (key) => {
      return isUuid(key)
    }
  })

  useEffect(() => {
    restClient.get('/jason/api/schema')
    .then(({ data: snakey_schema }) => {
      const schema = camelizeKeys(snakey_schema)

      const serverActionQueue = createServerActionQueue()

      const consumer = createConsumer()
      const allReducers = {
        ...reducers,
        ...createJasonReducers(schema)
      }

      console.log({ schema, allReducers })
      const store = configureStore({ reducer: allReducers, middleware })

      let payloadHandlers = {}
      function handlePayload(payload) {
        const { model, md5Hash } = payload
        console.log({ md5Hash, fn: `${model}:${md5Hash}`, payloadHandlers, model: _.camelCase(model), payload })
        const handler = payloadHandlers[`${_.camelCase(model)}:${md5Hash}`]
        if (handler) {
          handler({ ...payload, model: _.camelCase(model) })
        }
      }

      const subscription = (consumer.subscriptions.create({
        channel: 'Jason::Channel'
      }, {
        connected: () => {
          setConnected(true)
        },
        received: payload => {
          console.log("Payload received", payload)
          handlePayload(payload)
        },
        disconnected: () => console.warn('Disconnected from ActionCable')
      }));

      console.log('sending message')
      subscription.send({ message: 'test' })

      function createSubscription(config) {
        const md5Hash = md5(JSON.stringify(config))
        console.log('Subscribe with', config, md5Hash)

        _.map(config, (v, model) => {
          payloadHandlers[`${model}:${md5Hash}`] = createPayloadHandler(store.dispatch, serverActionQueue, subscription, model, schema[model])
        })
        subscription.send({ createSubscription: config })

        return () => removeSubscription(config)
      }

      function removeSubscription(config) {
        subscription.send({ removeSubscription: config })
        const md5Hash = md5(JSON.stringify(config))
        _.map(config, (v, model) => {
          delete payloadHandlers[`${model}:${md5Hash}`]
        })
      }
      const optDis = createOptDis(schema, store.dispatch, restClient, serverActionQueue)
      const actions = createActions(schema, store, restClient, optDis, extraActions)
      const eager = makeEager(schema)

      console.log({ actions })

      setValue({
        actions: actions,
        subscribe: (config) => createSubscription(config),
        eager
      })
      setStore(store)
    })
  }, [])

  if(!(store && value && connected)) return <div /> // Wait for async fetch of schema to complete

  return <Provider store={store}>
    <JasonContext.Provider value={value}>{ children }</JasonContext.Provider>
  </Provider>
}

export default JasonProvider



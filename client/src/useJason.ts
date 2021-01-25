import createActions from './createActions'
import createJasonReducers from './createJasonReducers'
import createPayloadHandler from './createPayloadHandler'
import createOptDis from './createOptDis'
import createServerActionQueue from './createServerActionQueue'
import restClient from './restClient'
import pruneIdsMiddleware from './pruneIdsMiddleware'

import { createConsumer } from "@rails/actioncable"
import { createEntityAdapter, createSlice, createReducer, configureStore } from '@reduxjs/toolkit'

import makeEager from './makeEager'
import { camelizeKeys } from 'humps'
import md5 from 'blueimp-md5'
import _ from 'lodash'
import React, { useState, useEffect } from 'react'

export default function useJason({ reducers, middleware = [], extraActions }: { reducers?: any, middleware?: any[], extraActions?: any }) {
  const [store, setStore] = useState(null as any)
  const [value, setValue] = useState(null as any)
  const [connected, setConnected] = useState(false)

  useEffect(() => {
    restClient.get('/jason/api/schema')
    .then(({ data: snakey_schema }) => {
      const schema = camelizeKeys(snakey_schema)
      console.log({ schema })

      const serverActionQueue = createServerActionQueue()

      const consumer = createConsumer()
      const allReducers = {
        ...reducers,
        ...createJasonReducers(schema)
      }

      console.log({ allReducers })

      const store = configureStore({ reducer: allReducers, middleware: [...middleware, pruneIdsMiddleware(schema)] })

      let payloadHandlers = {}
      function handlePayload(payload) {
        const { model, md5Hash } = payload
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
          handlePayload(payload)
        },
        disconnected: () => {
          setConnected(false)
          console.warn('Disconnected from ActionCable')
        }
      }));

      function createSubscription(config) {
        const md5Hash = md5(JSON.stringify(config))

        _.map(config, (v, model) => {
          payloadHandlers[`${model}:${md5Hash}`] = createPayloadHandler(store.dispatch, serverActionQueue, subscription, model, schema[model], md5Hash)
        })
        subscription.send({ createSubscription: config })

        return {
          remove: () => removeSubscription(config),
          md5Hash
        }
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

      setValue({
        actions: actions,
        subscribe: (config) => createSubscription(config),
        eager,
        handlePayload
      })
      setStore(store)
    })
  }, [])

  return [store, value, connected]
}
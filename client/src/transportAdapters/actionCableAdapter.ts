import { createConsumer } from "@rails/actioncable"
import restClient from '../restClient'
import { v4 as uuidv4 } from 'uuid'
import _ from 'lodash'

export default function actionCableAdapter(jasonConfig, handlePayload, dispatch, onConnected, transportOptions) {
  const consumerId = uuidv4()

  const { cableUrl } = transportOptions
  const consumer = cableUrl ? createConsumer(cableUrl) : createConsumer()

  const subscription = (consumer.subscriptions.create({
    channel: 'Jason::Channel'
  }, {
    connected: () => {
      dispatch({ type: 'jason/upsert', payload: { connected: true } })
      console.debug('Connected to ActionCable')

      // When AC loses connection - all state is lost, so we need to re-initialize all subscriptions
      onConnected()
    },
    received: payload => {
      handlePayload(payload)
      console.debug("ActionCable Payload received: ", payload)
    },
    disconnected: () => {
      dispatch({ type: 'jason/upsert', payload: { connected: false } })
      console.warn('Disconnected from ActionCable')
    }
  }));

  function createSubscription(config) {
    subscription.send({ createSubscription: config })
  }

  function removeSubscription(config) {
    restClient.post('/jason/api/remove_subscription', { config, consumerId })
    .catch(e => {
      console.error(e)
      Promise.reject(e)
    })
  }

  function getPayload(config, options) {
    restClient.post('/jason/api/get_payload', {
      config,
      options
    })
    .then(({ data }) => {
      _.map(data, (payload, modelName) => {
        handlePayload(payload)
      })
    })
    .catch(e => {
      console.error(e)
      Promise.reject(e)
    })
  }

  function fullChannelName(channelName) {
    return channelName
  }

  return { getPayload, createSubscription, removeSubscription }
}
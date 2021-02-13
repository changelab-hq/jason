import { createConsumer } from "@rails/actioncable"

export default function actionCableAdapter(jasonConfig, handlePayload, dispatch, onConnected) {
  const consumer = createConsumer()
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

  function getPayload(config, options) {
    subscription.send({ getPayload: config, ...options })
  }

  function createSubscription(config) {
    subscription.send({ createSubscription: config })
  }

  function removeSubscription(config) {
    subscription.send({ removeSubscription: config })
  }

  return { getPayload, createSubscription, removeSubscription }
}
import JasonContext from './JasonContext'
import { useContext } from 'react'

export default function useAct() {
  const { actions } = useContext(JasonContext)

  return actions
}


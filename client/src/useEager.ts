import JasonContext from './JasonContext'
import { useContext } from 'react'

export default function useEager(entity, id = null, relations = []) {
  const { eager } = useContext(JasonContext)

  return eager(entity, id, relations)
}


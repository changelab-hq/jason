import JasonContext from './JasonContext'
import { useContext, useEffect } from 'react'

export default function useSub(config) {
  const subscribe = useContext(JasonContext).subscribe

  useEffect(() => {
    // @ts-ignore
    return subscribe(config)
  }, [])
}

import JasonContext from './JasonContext'
import { useContext, useEffect } from 'react'

export default function useSub(config, options = {}) {
  // useEffect uses strict equality
  const configJson = JSON.stringify(config)
  const subscribe = useContext(JasonContext).subscribe

  useEffect(() => {
    // @ts-ignore
    return subscribe(config, options).remove
  }, [configJson])
}

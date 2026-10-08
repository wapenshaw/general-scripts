/** `$.clock.now()` of the last main-thread response; null while disarmed. */
export type ArmedAt = number | null

declare module 'claude-code' {
  interface PluginState {
    'cache-cold-compact': { armedAt: ArmedAt; isPaused: boolean }
  }
}

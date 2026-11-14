export type Vec3 = [number, number, number]

export type SoundState = {
  id: number
  src: string
  volume: number
  distance: number
  falloff: number
  loop: boolean
  paused: boolean
  position: number
  spatial: boolean
}

const SMOOTHING = 0.05
const DRIFT_TOLERANCE = 0.3

let context: AudioContext | undefined

export function audio(): AudioContext {
  context ??= new AudioContext()
  if (context.state === 'suspended') void context.resume()
  return context
}

export function toAudioSpace([x, y, z]: Vec3): Vec3 {
  return [x, z, -y]
}

export function glide(params: AudioParam[], values: Vec3 | number[]): void {
  const now = audio().currentTime
  params.forEach((param, index) => param.setTargetAtTime(values[index], now, SMOOTHING))
}

function isRemote(src: string): boolean {
  return !src.startsWith(`https://cfx-nui-`)
}

export class Voice {
  private element: HTMLAudioElement
  private gain?: GainNode
  private panner?: PannerNode
  private nodes: AudioNode[] = []
  private attenuation = 0
  private state: SoundState
  private syncedAt: number

  constructor(
    state: SoundState,
    private readonly onDuration: (id: number, duration: number) => void,
  ) {
    this.state = state
    this.syncedAt = performance.now()
    this.element = this.createElement(true)
  }

  update(state: SoundState): void {
    this.state = state
    this.syncedAt = performance.now()
    this.apply()
  }

  place(source: Vec3, listener: Vec3): void {
    const distance = Math.hypot(source[0] - listener[0], source[1] - listener[1], source[2] - listener[2])
    this.attenuation = Math.max(0, 1 - distance / this.state.distance) ** this.state.falloff

    if (this.panner) {
      const panner = this.panner
      glide([panner.positionX, panner.positionY, panner.positionZ], toAudioSpace(source))
    }

    this.applyLevel()
  }

  destroy(): void {
    this.element.pause()
    this.element.removeAttribute('src')
    this.element.load()
    this.nodes.forEach((node) => node.disconnect())
    this.nodes = []
    this.gain = undefined
    this.panner = undefined
  }

  private createElement(routed: boolean): HTMLAudioElement {
    const element = new Audio()
    const remote = isRemote(this.state.src)

    if (routed && remote) element.crossOrigin = 'anonymous'

    element.preload = 'auto'
    element.loop = this.state.loop
    element.addEventListener('loadedmetadata', () => {
      if (Number.isFinite(element.duration)) this.onDuration(this.state.id, element.duration)
      this.apply()
    })
    element.addEventListener('error', () => {
      if (!routed || !remote || element !== this.element) return
      this.destroy()
      this.element = this.createElement(false)
    })
    element.src = this.state.src

    if (routed) this.route(element)

    return element
  }

  private route(element: HTMLAudioElement): void {
    const ctx = audio()
    const source = ctx.createMediaElementSource(element)

    this.gain = ctx.createGain()
    this.gain.gain.value = this.state.spatial ? 0 : this.state.volume
    this.nodes = [source, this.gain]
    source.connect(this.gain)

    if (!this.state.spatial) {
      this.gain.connect(ctx.destination)
      return
    }

    this.panner = new PannerNode(ctx, { panningModel: 'HRTF', distanceModel: 'linear', rolloffFactor: 0 })
    this.nodes.push(this.panner)
    this.gain.connect(this.panner).connect(ctx.destination)
  }

  private playhead(): number {
    if (this.state.paused) return this.state.position
    return this.state.position + (performance.now() - this.syncedAt) / 1000
  }

  private apply(): void {
    const element = this.element
    const duration = element.duration
    const known = Number.isFinite(duration) && duration > 0
    let position = this.playhead()

    element.loop = this.state.loop

    if (known && this.state.loop) position %= duration

    if (known && position >= duration) {
      element.pause()
      return
    }

    const drifted = Math.abs(element.currentTime - position) > DRIFT_TOLERANCE

    if (element.readyState >= HTMLMediaElement.HAVE_METADATA && drifted) element.currentTime = position

    if (this.state.paused) element.pause()
    else void element.play().catch(() => undefined)

    this.applyLevel()
  }

  private applyLevel(): void {
    const level = this.state.volume * (this.state.spatial ? this.attenuation : 1)

    if (this.gain) glide([this.gain.gain], [level])
    else this.element.volume = Math.min(Math.max(level, 0), 1)
  }
}

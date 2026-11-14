import { audio, glide, toAudioSpace, Voice, type SoundState, type Vec3 } from './voice'

type Listener = { position: Vec3; forward: Vec3; up: Vec3 }

type Message =
  | { action: 'load'; sound: SoundState }
  | { action: 'update'; sound: SoundState }
  | { action: 'unload'; id: number }
  | { action: 'frame'; listener: Listener; sources: [number, number, number, number][] }
  | { action: 'frontend'; src: string; volume: number }

declare function GetParentResourceName(): string

const voices = new Map<number, Voice>()

function post(name: string, body: object): Promise<Response> {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body),
  })
}

function reportDuration(id: number, duration: number): void {
  void post('duration', { id, duration }).catch(() => undefined)
}

function moveListener({ position, forward, up }: Listener): void {
  const listener = audio().listener
  const [fx, fy, fz] = toAudioSpace(forward)
  const [ux, uy, uz] = toAudioSpace(up)

  glide([listener.positionX, listener.positionY, listener.positionZ], toAudioSpace(position))
  glide(
    [listener.forwardX, listener.forwardY, listener.forwardZ, listener.upX, listener.upY, listener.upZ],
    [fx, fy, fz, ux, uy, uz],
  )
}

function handle(message: Message): void {
  switch (message.action) {
    case 'load':
      voices.get(message.sound.id)?.destroy()
      voices.set(message.sound.id, new Voice(message.sound, reportDuration))
      return
    case 'update':
      voices.get(message.sound.id)?.update(message.sound)
      return
    case 'unload':
      voices.get(message.id)?.destroy()
      voices.delete(message.id)
      return
    case 'frame':
      moveListener(message.listener)
      for (const [id, x, y, z] of message.sources) voices.get(id)?.place([x, y, z], message.listener.position)
      return
    case 'frontend': {
      const element = new Audio(message.src)
      element.volume = message.volume
      void element.play().catch(() => undefined)
      return
    }
    default: {
      const _exhaustive: never = message
      return _exhaustive
    }
  }
}

function isMessage(data: unknown): data is Message {
  return typeof data === 'object' && data !== null && 'action' in data && typeof data.action === 'string'
}

window.addEventListener('message', (event: MessageEvent<unknown>) => {
  if (isMessage(event.data)) handle(event.data)
})

async function announceReady(): Promise<void> {
  for (;;) {
    const ready = await post('ready', {}).then((response) => response.ok, () => false)
    if (ready) return
    await new Promise((resolve) => setTimeout(resolve, 500))
  }
}

void announceReady()

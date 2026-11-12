// Logs what a tester needs to judge the reconnect UX: when the tab was hidden
// or shown, when the socket dropped and came back, and when each toast appeared,
// timed from the moment the tab became visible again.

const STORAGE_KEY = "reconnect-demo-timeline"
const TOASTS = {
  "client-error": "\"We can't find the internet\" toast",
  "server-error": "\"Something went wrong!\" toast",
}

let entries = []
// LiveView patches drop unknown attributes, so track watched toasts here
const watched = new WeakSet()
let shownAt = performance.now()

const load = () => {
  try { entries = JSON.parse(sessionStorage.getItem(STORAGE_KEY) || "[]") } catch (_e) { entries = [] }
}

const save = () => {
  try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify(entries.slice(-200))) } catch (_e) { /* private mode */ }
}

const render = () => {
  const list = document.getElementById("timeline")
  if (!list) { return }
  list.replaceChildren(...entries.map(({time, sinceShown, text, tone}) => {
    const li = document.createElement("li")
    const since = sinceShown == null ? "" : ` (+${sinceShown}ms after return)`
    li.textContent = `${time}  ${text}${since}`
    if (tone === "bad") { li.className = "text-error" }
    if (tone === "good") { li.className = "text-success" }
    return li
  }))
  list.scrollTop = list.scrollHeight
}

const log = (text, {tone, sinceReturn = false} = {}) => {
  const time = new Date().toLocaleTimeString([], {hour12: false})
  const visible = document.visibilityState === "visible"
  const sinceShown = sinceReturn && visible ? Math.round(performance.now() - shownAt) : null
  entries.push({time, sinceShown, text, tone})
  save()
  render()
}

const watchToasts = () => {
  for (const [id, label] of Object.entries(TOASTS)) {
    const el = document.getElementById(id)
    if (!el || watched.has(el)) { continue }
    watched.add(el)
    let visible = !el.hasAttribute("hidden")
    new MutationObserver(() => {
      const now = !el.hasAttribute("hidden")
      if (now === visible) { return }
      visible = now
      log(`${label} ${now ? "shown" : "hidden"}`, {tone: now ? "bad" : undefined, sinceReturn: true})
    }).observe(el, {attributes: true, attributeFilter: ["hidden"]})
  }
}

export function startTimeline(liveSocket, client) {
  load()
  const socket = liveSocket.getSocket()

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
      shownAt = performance.now()
      log("tab visible")
    } else {
      log("tab hidden")
    }
  })
  socket.onOpen(() => log("socket connected", {tone: "good", sinceReturn: true}))
  socket.onClose(() => log("socket closed", {sinceReturn: true}))
  window.addEventListener("phx:page-loading-start", ({detail}) => {
    if (detail.kind === "error") { log(`error state: ${detail.errorKind || "unknown"}`, {sinceReturn: true}) }
  })

  window.addEventListener("phx:page-loading-stop", () => {
    // the LiveView re-rendered, so make sure the timeline and toasts are wired
    render()
    watchToasts()
  })

  document.addEventListener("DOMContentLoaded", () => {
    render()
    watchToasts()
    for (const link of document.querySelectorAll("[data-client]")) {
      link.classList.toggle("btn-active", link.dataset.client === client)
    }
    document.getElementById("clear-timeline")?.addEventListener("click", () => {
      entries = []
      save()
      render()
    })
    log(`page loaded with the ${client} client`)
  })
}

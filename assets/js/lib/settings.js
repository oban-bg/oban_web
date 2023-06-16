const PREFIX = "oban:"

export function loadAll() {
  const values = {}

  for (const [key, json] of Object.entries(localStorage)) {
    if (key.startsWith(PREFIX)) values[key] = JSON.parse(json)
  }

  return values
}

export function load(key) {
  const json = localStorage.getItem(PREFIX + key)

  if (json) return JSON.parse(json)
}

export function store(key, value) {
  localStorage.setItem(PREFIX + key, JSON.stringify(value))
}

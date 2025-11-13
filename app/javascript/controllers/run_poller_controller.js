import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 3000 },
    status: String
  }

  connect() {
    if (this.statusValue === "pending") {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.poll()
    this.pollInterval = setInterval(() => {
      this.poll()
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json'
        }
      })

      if (!response.ok) {
        console.error('Poll failed:', response.statusText)
        return
      }

      const data = await response.json()

      // If status changed from pending, reload the page
      if (data.status !== 'pending') {
        this.stopPolling()
        window.location.reload()
      }
    } catch (error) {
      console.error('Poll error:', error)
    }
  }
}
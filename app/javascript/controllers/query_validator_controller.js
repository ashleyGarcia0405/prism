import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sql", "feedback", "submitButton", "estimatedEpsilon"]
  static values = { validateUrl: String }

  showDatasetInfo(event) {
    const datasetId = event.target.value

    if (!datasetId) {
      document.getElementById('dataset-info').classList.add('hidden')
      return
    }

    // Fetch dataset info
    fetch(`/datasets/${datasetId}.json`)
      .then(response => response.json())
      .then(data => {
        const infoBox = document.getElementById('dataset-info')
        const tableNameEl = document.getElementById('table-name')

        if (data.table_name) {
          tableNameEl.textContent = data.table_name
          infoBox.classList.remove('hidden')
        } else {
          infoBox.classList.add('hidden')
        }
      })
      .catch(error => {
        console.error('Error fetching dataset info:', error)
      })
  }

  connect() {
    this.timeout = null
  }

  validate() {
    clearTimeout(this.timeout)

    const sql = this.sqlTarget.value.trim()

    if (sql.length === 0) {
      this.clearFeedback()
      return
    }

    this.showValidating()

    this.timeout = setTimeout(() => {
      this.performValidation(sql)
    }, 500) // Debounce for 500ms
  }

  async performValidation(sql) {
    try {
      const response = await fetch(this.validateUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ sql: sql })
      })

      const data = await response.json()

      if (data.valid) {
        this.showValid(data.estimated_epsilon)
      } else {
        this.showInvalid(data.errors)
      }
    } catch (error) {
      console.error('Validation error:', error)
      this.showError()
    }
  }

  showValidating() {
    this.feedbackTarget.innerHTML = `
      <div class="bg-blue-900 bg-opacity-30 border border-blue-500 text-blue-200 px-4 py-3 rounded flex items-center">
        <svg class="animate-spin h-5 w-5 mr-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Validating query...
      </div>
    `
    this.submitButtonTarget.disabled = true
  }

  showValid(epsilon) {
    this.feedbackTarget.innerHTML = `
      <div class="bg-green-900 bg-opacity-30 border border-green-500 text-green-200 px-4 py-3 rounded">
        <div class="flex items-center">
          <svg class="h-5 w-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
          </svg>
          <span class="font-medium">Valid query</span>
        </div>
        <p class="mt-2 text-sm">Estimated privacy cost: <strong>${epsilon.toFixed(2)}ε</strong></p>
      </div>
    `
    this.submitButtonTarget.disabled = false

    if (this.hasEstimatedEpsilonTarget) {
      this.estimatedEpsilonTarget.textContent = `${epsilon.toFixed(2)}ε`
    }
  }

  showInvalid(errors) {
    const errorList = errors.map(error => `<li>${error}</li>`).join('')

    this.feedbackTarget.innerHTML = `
      <div class="bg-red-900 bg-opacity-30 border border-red-500 text-red-200 px-4 py-3 rounded">
        <div class="flex items-center mb-2">
          <svg class="h-5 w-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
          </svg>
          <span class="font-medium">Invalid query</span>
        </div>
        <ul class="list-disc list-inside text-sm space-y-1">
          ${errorList}
        </ul>
      </div>
    `
    this.submitButtonTarget.disabled = true
  }

  showError() {
    this.feedbackTarget.innerHTML = `
      <div class="bg-yellow-900 bg-opacity-30 border border-yellow-500 text-yellow-200 px-4 py-3 rounded">
        <p class="text-sm">Unable to validate query. You can still submit, but it may be rejected.</p>
      </div>
    `
    this.submitButtonTarget.disabled = false
  }

  clearFeedback() {
    this.feedbackTarget.innerHTML = ''
    this.submitButtonTarget.disabled = false
  }
}
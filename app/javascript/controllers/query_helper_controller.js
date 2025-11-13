import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
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
}
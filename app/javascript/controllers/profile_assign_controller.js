import { Controller } from "@hotwired/stimulus"

// Manual contract↔profile linking. A native <dialog> floats centered in the top
// layer (unaffected by scroll/transform ancestors). The profile picker is a
// searchable combobox: typing filters the options, clicking one selects it.
// "Aplicar" writes the choice into the row's hidden input so the whole form
// can be saved at once.
export default class extends Controller {
  static targets = ["dialog", "info", "query", "option", "empty", "input", "label"]

  open(event) {
    const data = event.currentTarget.dataset
    this.activeContractId = data.contractId
    this.infoTarget.innerHTML = data.info

    // Reflect the row's current selection (if any)
    const current = this.inputFor(this.activeContractId)
    this.selectedValue = current ? current.value : ""
    this.selectedName = ""

    this.queryTarget.value = ""
    this.resetOptions()
    this.dialogTarget.showModal()
    this.queryTarget.focus()
  }

  filter() {
    const term = this.normalize(this.queryTarget.value)
    let visible = 0
    this.optionTargets.forEach((opt) => {
      const match = this.normalize(opt.dataset.name).includes(term)
      opt.parentElement.classList.toggle("hidden", !match)
      if (match) visible += 1
    })
    this.emptyTarget.classList.toggle("hidden", visible > 0)
  }

  select(event) {
    const opt = event.currentTarget
    this.selectedValue = opt.dataset.id
    this.selectedName = opt.dataset.label
    this.queryTarget.value = opt.dataset.id ? opt.dataset.label : ""
    this.highlight(opt)
  }

  apply() {
    const input = this.inputFor(this.activeContractId)
    const label = this.labelFor(this.activeContractId)

    if (input) input.value = this.selectedValue || ""
    if (label) {
      if (this.selectedValue) {
        label.textContent = this.selectedName
        label.className = "inline-flex items-center rounded-full bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 ring-1 ring-indigo-600/20"
      } else {
        label.textContent = label.dataset.empty
        label.className = "text-xs text-gray-400"
      }
    }
    this.close()
  }

  close() {
    this.dialogTarget.close()
  }

  // Clicking the backdrop (the dialog element itself) closes it
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  resetOptions() {
    this.optionTargets.forEach((opt) => {
      opt.parentElement.classList.remove("hidden")
      const selected = opt.dataset.id === (this.selectedValue || "")
      this.toggleSelected(opt, selected)
    })
    this.emptyTarget.classList.add("hidden")
  }

  highlight(selectedOpt) {
    this.optionTargets.forEach((opt) => this.toggleSelected(opt, opt === selectedOpt))
  }

  toggleSelected(opt, on) {
    opt.classList.toggle("bg-indigo-50", on)
    opt.classList.toggle("font-medium", on)
    opt.classList.toggle("text-indigo-700", on)
  }

  inputFor(contractId) {
    return this.inputTargets.find((el) => el.dataset.contractId === contractId)
  }

  labelFor(contractId) {
    return this.labelTargets.find((el) => el.dataset.contractId === contractId)
  }

  normalize(value) {
    return (value || "")
      .toString()
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .trim()
  }
}

import { Controller } from "@hotwired/stimulus"

// A tiny proof-of-life Stimulus controller. It runs when an element with
// data-controller="hello" appears on the page — no bundler, no build step,
// no node_modules. The import map in the layout wires "HelloController"
// to this file's fingerprinted URL.
export default class extends Controller {
  connect() {
    this.element.insertAdjacentHTML("beforeend", " <small>(js via import map — no npm)</small>")
  }
}

import { LightningElement, api } from "lwc";

export default class AdaActionPreview extends LightningElement {
  @api result;
  @api busy = false;

  _proposal;
  draft = "";

  @api
  get proposal() {
    return this._proposal;
  }
  set proposal(value) {
    this._proposal = value;
    this.draft = (value && value.notes) || "";
  }

  get sent() {
    return !!this.result && this.result.success === true;
  }

  get failed() {
    return !!this.result && this.result.success !== true;
  }

  get notesChanged() {
    return this.draft !== ((this._proposal && this._proposal.notes) || "");
  }

  get notesLocked() {
    return this.sent;
  }

  get refreshDisabled() {
    return this.busy || this.sent || !this.notesChanged;
  }

  get confirmDisabled() {
    return this.busy || this.sent || this.notesChanged;
  }

  handleNotesChange(event) {
    this.draft = event.detail.value || "";
  }

  handleRefresh() {
    if (this.refreshDisabled) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("previewrefresh", { detail: { notes: this.draft } })
    );
  }

  handleConfirm() {
    if (this.confirmDisabled) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("confirm", { detail: { notes: this.draft } })
    );
  }
}

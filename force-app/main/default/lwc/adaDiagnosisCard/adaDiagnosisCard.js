import { LightningElement, api } from "lwc";

export default class AdaDiagnosisCard extends LightningElement {
  @api diagnosis;
  @api explanation;
  @api proposal;
  @api feedbackGiven = false;
  @api busy = false;

  @api
  focusHeading() {
    const heading = this.template.querySelector('[data-id="headline"]');
    if (heading) {
      heading.focus();
    }
  }

  get isConfident() {
    return !!this.diagnosis && this.diagnosis.confident === true;
  }

  get confidenceText() {
    const value = Number(this.diagnosis && this.diagnosis.confidence);
    const percent = Number.isFinite(value) ? Math.round(value * 100) : 0;
    return `Confidence: ${percent}%`;
  }

  get showComponent() {
    return (
      this.isConfident &&
      !!(this.diagnosis.componentLabel || this.diagnosis.componentApiName)
    );
  }

  get componentText() {
    const label = this.diagnosis.componentLabel;
    const apiName = this.diagnosis.componentApiName;
    if (label && apiName && label !== apiName) {
      return `${label} (${apiName})`;
    }
    return label || apiName;
  }

  get hasSteps() {
    return (
      !!this.explanation &&
      Array.isArray(this.explanation.fixSteps) &&
      this.explanation.fixSteps.length > 0
    );
  }

  get steps() {
    if (!this.hasSteps) {
      return [];
    }
    return this.explanation.fixSteps.map((text, index) => ({
      key: `step-${index}`,
      text
    }));
  }

  get hasSources() {
    return (
      this.isConfident &&
      !!this.explanation &&
      Array.isArray(this.explanation.sources) &&
      this.explanation.sources.length > 0
    );
  }

  get citations() {
    if (!this.hasSources) {
      return [];
    }
    return this.explanation.sources.map((text, index) => ({
      key: `source-${index}`,
      text
    }));
  }

  get showSource() {
    return (
      this.isConfident &&
      !!this.explanation &&
      !!this.explanation.source &&
      this.explanation.source !== "None"
    );
  }

  get sourceText() {
    if (this.explanation.source === "LLM") {
      return "Explained by an AI model. Check the steps before you act on them.";
    }
    return this.explanation.usedFallback
      ? "Standard guidance (the AI model could not be reached)."
      : "Standard guidance.";
  }

  get showFeedback() {
    return this.isConfident && !!this.explanation;
  }

  get showReportButton() {
    return !!this.diagnosis && !this.isConfident && !this.proposal;
  }

  handleSolved() {
    this.dispatchEvent(
      new CustomEvent("feedback", { detail: { solved: true } })
    );
  }

  handleNotSolved() {
    this.dispatchEvent(
      new CustomEvent("feedback", { detail: { solved: false } })
    );
  }

  handleReport() {
    this.dispatchEvent(new CustomEvent("reportrequest"));
  }
}

import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import diagnose from "@salesforce/apex/ADA_AgentController.diagnose";
import explain from "@salesforce/apex/ADA_AgentController.explain";
import proposeAction from "@salesforce/apex/ADA_AgentController.proposeAction";
import confirmAction from "@salesforce/apex/ADA_AgentController.confirmAction";
import recordFeedback from "@salesforce/apex/ADA_AgentController.recordFeedback";
import askFollowUp from "@salesforce/apex/ADA_AgentController.askFollowUp";

const GENERIC_ERROR = "Something went wrong. Try again.";

export default class AdaHelpPanel extends LightningElement {
  @api recordId;

  errorText = "";
  diagnosis = null;
  explanation = null;
  followUps = [];
  followUpsLeft = 0;
  proposal = null;
  confirmResult = null;
  feedbackGiven = false;
  errorMessage = null;
  busy = false;
  statusText = "";

  pageReference;
  feedbackPending = false;
  focusResultPending = false;

  @wire(CurrentPageReference)
  wiredPageReference(pageReference) {
    this.pageReference = pageReference;
  }

  renderedCallback() {
    if (!this.focusResultPending) {
      return;
    }
    const card = this.template.querySelector("c-ada-diagnosis-card");
    if (card) {
      this.focusResultPending = false;
      card.focusHeading();
    }
  }

  get effectiveRecordId() {
    if (this.recordId) {
      return this.recordId;
    }
    const attributes = this.pageReference && this.pageReference.attributes;
    return (attributes && attributes.recordId) || null;
  }

  get diagnoseDisabled() {
    return this.busy || !this.errorText || this.errorText.trim() === "";
  }

  get hasResult() {
    return !!this.diagnosis;
  }

  handleTextChange(event) {
    this.errorText = event.detail.value;
  }

  async handleDiagnose() {
    if (this.busy || this.diagnoseDisabled) {
      return;
    }
    this.busy = true;
    this.statusText = "Looking into it…";
    this.errorMessage = null;
    this.diagnosis = null;
    this.explanation = null;
    this.followUps = [];
    this.followUpsLeft = 0;
    this.proposal = null;
    this.confirmResult = null;
    this.feedbackGiven = false;
    this.feedbackPending = false;
    try {
      this.diagnosis = await diagnose({
        errorText: this.errorText,
        recordId: this.effectiveRecordId
      });
      this.focusResultPending = true;
      this.explanation = await explain({
        sessionKey: this.diagnosis.sessionKey,
        userQuestion: null
      });
      this.followUpsLeft =
        typeof this.explanation.followUpsLeft === "number"
          ? this.explanation.followUpsLeft
          : 0;
    } catch (error) {
      this.errorMessage = this.readError(error);
    } finally {
      this.busy = false;
      this.statusText = "";
    }
  }

  async handleReportRequest() {
    if (this.busy || this.proposal || !this.diagnosis) {
      return;
    }
    await this.prepare("Preparing the report…", null);
  }

  async handlePreviewRefresh(event) {
    if (this.busy || !this.proposal || this.confirmResult?.success) {
      return;
    }
    await this.prepare("Updating the preview…", event.detail.notes);
  }

  async prepare(status, userNotes) {
    this.busy = true;
    this.statusText = status;
    this.errorMessage = null;
    try {
      this.proposal = await proposeAction({
        sessionKey: this.diagnosis.sessionKey,
        actionType: "RAISE_BUG",
        userNotes
      });
      this.confirmResult = null;
    } catch (error) {
      this.errorMessage = this.readError(error);
    } finally {
      this.busy = false;
      this.statusText = "";
    }
  }

  async handleConfirm(event) {
    if (
      this.busy ||
      !this.proposal ||
      !this.diagnosis ||
      this.confirmResult?.success
    ) {
      return;
    }
    this.busy = true;
    this.statusText = "Sending the report…";
    this.errorMessage = null;
    try {
      this.confirmResult = await confirmAction({
        sessionKey: this.diagnosis.sessionKey,
        actionType: "RAISE_BUG",
        userNotes: event.detail.notes
      });
    } catch (error) {
      this.errorMessage = this.readError(error);
    } finally {
      this.busy = false;
      this.statusText = "";
    }
  }

  async handleFeedback(event) {
    if (this.feedbackPending || this.feedbackGiven || !this.diagnosis) {
      return;
    }
    this.feedbackPending = true;
    this.errorMessage = null;
    try {
      await recordFeedback({
        sessionKey: this.diagnosis.sessionKey,
        solved: event.detail.solved
      });
      this.feedbackGiven = true;
    } catch (error) {
      this.errorMessage = this.readError(error);
      this.feedbackPending = false;
    }
  }

  async handleFollowUp(event) {
    if (this.busy || !this.diagnosis) {
      return;
    }
    this.busy = true;
    this.statusText = "Looking into it…";
    this.errorMessage = null;
    try {
      const answer = await askFollowUp({
        sessionKey: this.diagnosis.sessionKey,
        question: event.detail.question
      });
      this.followUps = [
        ...this.followUps,
        {
          question: event.detail.question,
          summary: answer.summary,
          fixSteps: answer.fixSteps
        }
      ];
      this.followUpsLeft = answer.followUpsLeft;
    } catch (error) {
      this.errorMessage = this.readError(error);
    } finally {
      this.busy = false;
      this.statusText = "";
    }
  }

  handleStartOver() {
    this.errorText = "";
    this.diagnosis = null;
    this.explanation = null;
    this.followUps = [];
    this.followUpsLeft = 0;
    this.proposal = null;
    this.confirmResult = null;
    this.feedbackGiven = false;
    this.feedbackPending = false;
    this.errorMessage = null;
    this.statusText = "";
  }

  readError(error) {
    const message = error && error.body && error.body.message;
    return typeof message === "string" && message ? message : GENERIC_ERROR;
  }
}

import { createElement } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import AdaHelpPanel from "c/adaHelpPanel";
import diagnose from "@salesforce/apex/ADA_AgentController.diagnose";
import explain from "@salesforce/apex/ADA_AgentController.explain";
import proposeAction from "@salesforce/apex/ADA_AgentController.proposeAction";
import confirmAction from "@salesforce/apex/ADA_AgentController.confirmAction";
import recordFeedback from "@salesforce/apex/ADA_AgentController.recordFeedback";
import askFollowUp from "@salesforce/apex/ADA_AgentController.askFollowUp";

jest.mock(
  "@salesforce/apex/ADA_AgentController.askFollowUp",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ADA_AgentController.diagnose",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ADA_AgentController.explain",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ADA_AgentController.proposeAction",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ADA_AgentController.confirmAction",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ADA_AgentController.recordFeedback",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const KEY = "0123456789abcdef0123456789abcdef";
const CONFIDENT = {
  sessionKey: KEY,
  errorType: "VALIDATION_RULE",
  headline: "This looks like a validation rule: Close Date Rule.",
  confidence: 0.98,
  confident: true,
  objectApiName: "Opportunity",
  componentApiName: "Close_Date_Rule",
  componentLabel: "Close Date Rule",
  allowedActions: ["EXPLAIN", "RAISE_BUG"]
};
const NOT_SURE = {
  sessionKey: KEY,
  errorType: "UNKNOWN",
  headline: "I'm not sure what's blocking you.",
  confidence: 0,
  confident: false,
  allowedActions: ["RAISE_BUG"]
};
const EXPLAINED = {
  sessionKey: KEY,
  summary: "The rule needs a future close date.",
  fixSteps: ["Open the deal.", "Set a future close date."],
  source: "LLM",
  cached: false,
  usedFallback: false,
  followUpsLeft: 3,
  allowedActions: ["EXPLAIN", "RAISE_BUG"]
};
const NOT_SURE_EXPLANATION = {
  sessionKey: KEY,
  summary: "I'm not sure what's blocking you. I can pass the details on.",
  fixSteps: [],
  source: "None",
  allowedActions: ["RAISE_BUG"]
};

function build(props = {}) {
  const element = createElement("c-ada-help-panel", { is: AdaHelpPanel });
  Object.assign(element, props);
  document.body.appendChild(element);
  return element;
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function q(element, id) {
  return element.shadowRoot.querySelector(`[data-id="${id}"]`);
}

function preview(element) {
  return element.shadowRoot.querySelector("c-ada-action-preview");
}

const PROPOSAL = {
  sessionKey: KEY,
  actionType: "RAISE_BUG",
  title: "ADA: UNKNOWN",
  payloadJson: '{"title":"ADA: UNKNOWN"}',
  notes: "",
  requiresConfirmation: true
};

async function propose(element) {
  card(element).dispatchEvent(new CustomEvent("reportrequest"));
  await flush();
  await flush();
}

function card(element) {
  return element.shadowRoot.querySelector("c-ada-diagnosis-card");
}

function type(element, text) {
  const input = q(element, "error-text");
  input.value = text;
  input.dispatchEvent(new CustomEvent("change", { detail: { value: text } }));
}

async function submit(element, text = "Close date cannot be in the past.") {
  type(element, text);
  await flush();
  q(element, "diagnose").click();
  await flush();
  await flush();
}

describe("c-ada-help-panel", () => {
  beforeEach(() => {
    diagnose.mockReset();
    explain.mockReset();
    proposeAction.mockReset();
    confirmAction.mockReset();
    recordFeedback.mockReset();
    askFollowUp.mockReset();
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("starts idle with a labelled paste box and a disabled diagnose button", () => {
    const element = build();
    const input = q(element, "error-text");
    expect(input.label).toBe("Paste the error message");
    expect(q(element, "diagnose").label).toBe("Diagnose");
    expect(q(element, "diagnose").disabled).toBe(true);
    expect(card(element)).toBeNull();
    expect(q(element, "error")).toBeNull();
    expect(q(element, "start-over")).toBeNull();
  });

  it("enables the button once there is text, not for blanks", async () => {
    const element = build();
    type(element, "   ");
    await flush();
    expect(q(element, "diagnose").disabled).toBe(true);
    type(element, "Something failed");
    await flush();
    expect(q(element, "diagnose").disabled).toBe(false);
  });

  it("diagnoses and explains, passing the record id from the page reference", async () => {
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockResolvedValue(EXPLAINED);
    const element = build();
    CurrentPageReference.emit({
      type: "standard__recordPage",
      attributes: { recordId: "006000000000001AAA" }
    });
    await submit(element, "Close date cannot be in the past.");
    expect(diagnose).toHaveBeenCalledWith({
      errorText: "Close date cannot be in the past.",
      recordId: "006000000000001AAA"
    });
    expect(explain).toHaveBeenCalledWith({
      sessionKey: KEY,
      userQuestion: null
    });
    const result = card(element);
    expect(result.diagnosis).toEqual(CONFIDENT);
    expect(result.explanation).toEqual(EXPLAINED);
    expect(q(element, "error")).toBeNull();
    expect(q(element, "start-over")).not.toBeNull();
  });

  it("prefers an explicit record id over the page reference", async () => {
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockResolvedValue(EXPLAINED);
    const element = build({ recordId: "006000000000002AAA" });
    CurrentPageReference.emit({
      attributes: { recordId: "006000000000001AAA" }
    });
    await submit(element);
    expect(diagnose.mock.calls[0][0].recordId).toBe("006000000000002AAA");
  });

  it("sends a null record id when the page has none", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    const element = build();
    CurrentPageReference.emit({ type: "standard__namedPage", attributes: {} });
    await submit(element);
    expect(diagnose.mock.calls[0][0].recordId).toBeNull();
  });

  it("shows a busy status and ignores a second click while diagnosing", async () => {
    let finish;
    diagnose.mockReturnValue(new Promise((resolve) => (finish = resolve)));
    explain.mockResolvedValue(EXPLAINED);
    const element = build();
    type(element, "Some error");
    await flush();
    q(element, "diagnose").click();
    await flush();
    expect(q(element, "status").textContent).toContain("Looking");
    expect(q(element, "diagnose").disabled).toBe(true);
    q(element, "diagnose").click();
    expect(diagnose).toHaveBeenCalledTimes(1);
    finish(CONFIDENT);
    await flush();
    await flush();
    expect(q(element, "status").textContent).toBe("");
  });

  it("marks the status as a polite live region", () => {
    const status = q(build(), "status");
    expect(status.getAttribute("aria-live")).toBe("polite");
    expect(status.getAttribute("role")).toBe("status");
  });

  it("handles low confidence: not-sure text and a report offer, no feedback", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    const element = build();
    await submit(element, "Something odd happened.");
    const result = card(element);
    expect(result.diagnosis.confident).toBe(false);
    expect(result.explanation.fixSteps).toEqual([]);
    expect(result.proposal).toBeFalsy();
  });

  it("prepares the report for a low-confidence answer and shows the preview", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    proposeAction.mockResolvedValue(PROPOSAL);
    const element = build();
    await submit(element);
    expect(preview(element)).toBeNull();
    await propose(element);
    expect(proposeAction).toHaveBeenCalledWith({
      sessionKey: KEY,
      actionType: "RAISE_BUG",
      userNotes: null
    });
    expect(card(element).proposal.title).toBe("ADA: UNKNOWN");
    expect(preview(element).proposal).toEqual(PROPOSAL);
    expect(confirmAction).not.toHaveBeenCalled();
  });

  it("refreshes the preview with the notes the person typed", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    proposeAction.mockResolvedValueOnce(PROPOSAL);
    const element = build();
    await submit(element);
    await propose(element);
    const withNotes = { ...PROPOSAL, notes: "Happens on every save." };
    proposeAction.mockResolvedValueOnce(withNotes);
    preview(element).dispatchEvent(
      new CustomEvent("previewrefresh", {
        detail: { notes: "Happens on every save." }
      })
    );
    await flush();
    await flush();
    expect(proposeAction).toHaveBeenLastCalledWith({
      sessionKey: KEY,
      actionType: "RAISE_BUG",
      userNotes: "Happens on every save."
    });
    expect(preview(element).proposal).toEqual(withNotes);
    expect(confirmAction).not.toHaveBeenCalled();
  });

  it("confirms once and shows the result, even if confirm is clicked twice", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    proposeAction.mockResolvedValue(PROPOSAL);
    let finish;
    confirmAction.mockReturnValue(new Promise((resolve) => (finish = resolve)));
    const element = build();
    await submit(element);
    await propose(element);
    const detail = { detail: { notes: "" } };
    preview(element).dispatchEvent(new CustomEvent("confirm", detail));
    preview(element).dispatchEvent(new CustomEvent("confirm", detail));
    await flush();
    expect(q(element, "status").textContent).toContain("Sending");
    expect(preview(element).busy).toBe(true);
    finish({
      sessionKey: KEY,
      success: true,
      status: "Success",
      message: "Your admin team was emailed the report."
    });
    await flush();
    await flush();
    expect(confirmAction).toHaveBeenCalledTimes(1);
    expect(confirmAction).toHaveBeenCalledWith({
      sessionKey: KEY,
      actionType: "RAISE_BUG",
      userNotes: ""
    });
    expect(preview(element).result.success).toBe(true);
    expect(preview(element).busy).toBe(false);
    expect(q(element, "status").textContent).toBe("");
  });

  it("does not confirm again after a success", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    proposeAction.mockResolvedValue(PROPOSAL);
    confirmAction.mockResolvedValue({ success: true, message: "Sent." });
    const element = build();
    await submit(element);
    await propose(element);
    const detail = { detail: { notes: "" } };
    preview(element).dispatchEvent(new CustomEvent("confirm", detail));
    await flush();
    await flush();
    preview(element).dispatchEvent(new CustomEvent("confirm", detail));
    await flush();
    expect(confirmAction).toHaveBeenCalledTimes(1);
  });

  it("shows a failed send and allows another try", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    proposeAction.mockResolvedValue(PROPOSAL);
    confirmAction.mockResolvedValueOnce({
      success: false,
      status: "Failed",
      message: "The report could not be sent."
    });
    const element = build();
    await submit(element);
    await propose(element);
    const detail = { detail: { notes: "" } };
    preview(element).dispatchEvent(new CustomEvent("confirm", detail));
    await flush();
    await flush();
    expect(preview(element).result.message).toBe(
      "The report could not be sent."
    );
    confirmAction.mockResolvedValueOnce({ success: true, message: "Sent." });
    preview(element).dispatchEvent(new CustomEvent("confirm", detail));
    await flush();
    await flush();
    expect(confirmAction).toHaveBeenCalledTimes(2);
    expect(preview(element).result.success).toBe(true);
  });

  it("shows a server error from confirm in an alert", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    proposeAction.mockResolvedValue(PROPOSAL);
    confirmAction.mockRejectedValue({
      body: { message: "Session not found. Start again." }
    });
    const element = build();
    await submit(element);
    await propose(element);
    preview(element).dispatchEvent(
      new CustomEvent("confirm", { detail: { notes: "" } })
    );
    await flush();
    await flush();
    expect(q(element, "error").textContent).toContain("Session not found");
    expect(preview(element).busy).toBe(false);
  });

  it("clears the preview and result on start over", async () => {
    diagnose.mockResolvedValue(NOT_SURE);
    explain.mockResolvedValue(NOT_SURE_EXPLANATION);
    proposeAction.mockResolvedValue(PROPOSAL);
    confirmAction.mockResolvedValue({ success: true, message: "Sent." });
    const element = build();
    await submit(element);
    await propose(element);
    preview(element).dispatchEvent(
      new CustomEvent("confirm", { detail: { notes: "" } })
    );
    await flush();
    await flush();
    q(element, "start-over").click();
    await flush();
    expect(preview(element)).toBeNull();
    await submit(element, "Another problem.");
    await propose(element);
    expect(preview(element).result).toBeFalsy();
  });

  it("records feedback once and tells the card", async () => {
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockResolvedValue(EXPLAINED);
    recordFeedback.mockResolvedValue(undefined);
    const element = build();
    await submit(element);
    const detail = { detail: { solved: true } };
    card(element).dispatchEvent(new CustomEvent("feedback", detail));
    card(element).dispatchEvent(new CustomEvent("feedback", detail));
    await flush();
    await flush();
    expect(recordFeedback).toHaveBeenCalledTimes(1);
    expect(recordFeedback).toHaveBeenCalledWith({
      sessionKey: KEY,
      solved: true
    });
    expect(card(element).feedbackGiven).toBe(true);
  });

  it("shows a server error from diagnose in an alert and keeps the text", async () => {
    diagnose.mockRejectedValue({
      body: { message: "Paste the error message first." }
    });
    const element = build();
    await submit(element, "x");
    const alert = q(element, "error");
    expect(alert.getAttribute("role")).toBe("alert");
    expect(alert.textContent).toContain("Paste the error message first.");
    expect(card(element)).toBeNull();
    expect(q(element, "error-text").value).toBe("x");
    expect(explain).not.toHaveBeenCalled();
  });

  it("keeps the diagnosis visible when explain fails", async () => {
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockRejectedValue({
      body: { message: "Session not found. Start again." }
    });
    const element = build();
    await submit(element);
    expect(q(element, "error").textContent).toContain("Session not found");
    expect(card(element).diagnosis).toEqual(CONFIDENT);
    expect(card(element).explanation).toBeFalsy();
  });

  it("falls back to a generic message for an unreadable error", async () => {
    diagnose.mockRejectedValue(new Error("network"));
    const element = build();
    await submit(element);
    expect(q(element, "error").textContent).toContain("Something went wrong");
    expect(q(element, "error").textContent).not.toContain("network");
  });

  it("clears everything on start over", async () => {
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockResolvedValue(EXPLAINED);
    const element = build();
    await submit(element);
    q(element, "start-over").click();
    await flush();
    expect(card(element)).toBeNull();
    expect(q(element, "error-text").value).toBe("");
    expect(q(element, "diagnose").disabled).toBe(true);
    expect(q(element, "start-over")).toBeNull();
  });

  it("renders a hostile explanation as text only", async () => {
    const hostile = '<img src=x onerror="window.pwned=1">';
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockResolvedValue({
      ...EXPLAINED,
      summary: hostile,
      fixSteps: [hostile]
    });
    const element = build();
    await submit(element);
    const inner = card(element).shadowRoot;
    expect(inner.querySelector("img")).toBeNull();
    expect(inner.querySelector('[data-id="summary"]').textContent).toBe(
      hostile
    );
    expect(element.shadowRoot.querySelector("img")).toBeNull();
    expect(window.pwned).toBeUndefined();
  });

  it("can be used from the keyboard: textarea and native buttons only", async () => {
    const element = build();
    type(element, "Some error");
    await flush();
    const submitButton = q(element, "diagnose");
    expect(submitButton.tagName).toBe("LIGHTNING-BUTTON");
    expect(
      element.shadowRoot.querySelectorAll("[onclick], [tabindex]").length
    ).toBe(0);
  });

  it("asks a follow-up, adds the answer and counts down", async () => {
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockResolvedValue(EXPLAINED);
    askFollowUp.mockResolvedValue({
      sessionKey: KEY,
      summary: "Enter a date after today.",
      fixSteps: ["Pick tomorrow."],
      source: "LLM",
      followUpsLeft: 2
    });
    const element = build();
    await submit(element);
    expect(card(element).followUpsLeft).toBe(3);
    card(element).dispatchEvent(
      new CustomEvent("followup", { detail: { question: "What do I enter?" } })
    );
    await flush();
    await flush();
    expect(askFollowUp).toHaveBeenCalledWith({
      sessionKey: KEY,
      question: "What do I enter?"
    });
    expect(card(element).followUpsLeft).toBe(2);
    expect(card(element).followUps.length).toBe(1);
    expect(card(element).followUps[0].question).toBe("What do I enter?");
    expect(card(element).followUps[0].summary).toBe(
      "Enter a date after today."
    );
    expect(q(element, "error")).toBeNull();
  });

  it("shows the server message when a follow-up is refused", async () => {
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockResolvedValue(EXPLAINED);
    askFollowUp.mockRejectedValue({
      body: { message: "You can ask 3 follow-up questions for each problem." }
    });
    const element = build();
    await submit(element);
    card(element).dispatchEvent(
      new CustomEvent("followup", { detail: { question: "More?" } })
    );
    await flush();
    await flush();
    expect(q(element, "error").textContent).toContain("3 follow-up");
    expect(card(element).followUps.length).toBe(0);
    expect(card(element).followUpsLeft).toBe(3);
  });

  it("clears follow-ups on start over", async () => {
    diagnose.mockResolvedValue(CONFIDENT);
    explain.mockResolvedValue(EXPLAINED);
    askFollowUp.mockResolvedValue({
      sessionKey: KEY,
      summary: "A.",
      fixSteps: [],
      source: "Template",
      followUpsLeft: 2
    });
    const element = build();
    await submit(element);
    card(element).dispatchEvent(
      new CustomEvent("followup", { detail: { question: "Q?" } })
    );
    await flush();
    await flush();
    q(element, "start-over").click();
    await flush();
    diagnose.mockResolvedValue(CONFIDENT);
    await submit(element);
    expect(card(element).followUps.length).toBe(0);
    expect(card(element).followUpsLeft).toBe(3);
  });
});

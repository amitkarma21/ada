import { createElement } from "lwc";
import AdaDiagnosisCard from "c/adaDiagnosisCard";

const DIAGNOSIS = {
  headline: "This looks like a validation rule: Close Date Rule.",
  confidence: 0.98,
  confident: true,
  errorType: "VALIDATION_RULE",
  componentLabel: "Close Date Rule",
  componentApiName: "Close_Date_Rule"
};
const EXPLANATION = {
  summary: "The rule needs a future close date.",
  fixSteps: ["Open the deal.", "Set a future close date."],
  source: "LLM",
  usedFallback: false
};

function build(props = {}) {
  const element = createElement("c-ada-diagnosis-card", {
    is: AdaDiagnosisCard
  });
  Object.assign(element, props);
  document.body.appendChild(element);
  return element;
}

function q(element, id) {
  return element.shadowRoot.querySelector(`[data-id="${id}"]`);
}

describe("c-ada-diagnosis-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders nothing without a diagnosis", () => {
    const element = build();
    expect(element.shadowRoot.querySelector("section")).toBeNull();
  });

  it("shows the headline, confidence and component", async () => {
    const element = build({ diagnosis: DIAGNOSIS });
    expect(q(element, "headline").textContent).toBe(DIAGNOSIS.headline);
    expect(q(element, "confidence").textContent).toContain("98%");
    expect(q(element, "component").textContent).toContain("Close Date Rule");
    expect(q(element, "component").textContent).toContain("Close_Date_Rule");
  });

  it("labels the region and makes the heading focusable", () => {
    const element = build({ diagnosis: DIAGNOSIS });
    const region = element.shadowRoot.querySelector("section");
    expect(region.getAttribute("aria-label")).toBe("Diagnosis result");
    expect(q(element, "headline").getAttribute("tabindex")).toBe("-1");
  });

  it("shows the explanation and numbered fix steps", () => {
    const element = build({ diagnosis: DIAGNOSIS, explanation: EXPLANATION });
    expect(q(element, "summary").textContent).toBe(EXPLANATION.summary);
    const steps = element.shadowRoot.querySelectorAll('[data-id="step"]');
    expect(Array.from(steps).map((s) => s.textContent)).toEqual(
      EXPLANATION.fixSteps
    );
    expect(q(element, "source").textContent).toContain("AI model");
  });

  it("says when standard guidance was used and when it was a fallback", () => {
    const standard = build({
      diagnosis: DIAGNOSIS,
      explanation: { ...EXPLANATION, source: "Template" }
    });
    expect(q(standard, "source").textContent).toContain("Standard guidance");
    const fallback = build({
      diagnosis: DIAGNOSIS,
      explanation: { ...EXPLANATION, source: "Template", usedFallback: true }
    });
    expect(q(fallback, "source").textContent).toContain("could not be reached");
  });

  it("offers feedback for a confident explanation and reports the choice", () => {
    const element = build({ diagnosis: DIAGNOSIS, explanation: EXPLANATION });
    const handler = jest.fn();
    element.addEventListener("feedback", handler);
    q(element, "solved").click();
    q(element, "not-solved").click();
    expect(handler).toHaveBeenCalledTimes(2);
    expect(handler.mock.calls[0][0].detail).toEqual({ solved: true });
    expect(handler.mock.calls[1][0].detail).toEqual({ solved: false });
  });

  it("replaces the feedback buttons with a thank-you once given", async () => {
    const element = build({
      diagnosis: DIAGNOSIS,
      explanation: EXPLANATION,
      feedbackGiven: true
    });
    expect(q(element, "solved")).toBeNull();
    expect(q(element, "thanks").textContent).toContain("Thanks");
  });

  it("disables the buttons while busy", () => {
    const element = build({
      diagnosis: DIAGNOSIS,
      explanation: EXPLANATION,
      busy: true
    });
    expect(q(element, "solved").disabled).toBe(true);
    expect(q(element, "not-solved").disabled).toBe(true);
  });

  it("for low confidence shows no steps or feedback and offers only the report", () => {
    const element = build({
      diagnosis: {
        ...DIAGNOSIS,
        confident: false,
        confidence: 0.2,
        headline: "I'm not sure what's blocking you."
      },
      explanation: {
        summary: "I'm not sure what's blocking you. I can pass the details on.",
        fixSteps: [],
        source: "None"
      }
    });
    expect(q(element, "headline").textContent).toContain("not sure");
    expect(element.shadowRoot.querySelectorAll('[data-id="step"]').length).toBe(
      0
    );
    expect(q(element, "solved")).toBeNull();
    expect(q(element, "source")).toBeNull();
    const handler = jest.fn();
    element.addEventListener("reportrequest", handler);
    q(element, "report").click();
    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("hides the report button once a proposal exists", () => {
    const element = build({
      diagnosis: { ...DIAGNOSIS, confident: false },
      proposal: {
        title: "ADA: UNKNOWN",
        payloadJson: '{"title":"ADA: UNKNOWN"}'
      }
    });
    expect(q(element, "report")).toBeNull();
    expect(q(element, "payload")).toBeNull();
  });

  it("lists what the answer is based on", () => {
    const element = build({
      diagnosis: DIAGNOSIS,
      explanation: {
        ...EXPLANATION,
        sources: [
          "Validation rule: Close Date Future (Close_Date_Future) on Opportunity, last changed 2026-03-01"
        ]
      }
    });
    const items = element.shadowRoot.querySelectorAll('[data-id="citation"]');
    expect(items.length).toBe(1);
    expect(items[0].textContent).toContain("Close_Date_Future");
    expect(q(element, "sources").textContent).toContain("Based on");
  });

  it("shows no sources block when there are none", () => {
    const element = build({
      diagnosis: DIAGNOSIS,
      explanation: { ...EXPLANATION, sources: [] }
    });
    expect(q(element, "sources")).toBeNull();
    const old = build({ diagnosis: DIAGNOSIS, explanation: EXPLANATION });
    expect(q(old, "sources")).toBeNull();
  });

  it("renders markup from the server as plain text", () => {
    const hostile = '<img src=x onerror="window.pwned=1">';
    const element = build({
      diagnosis: { ...DIAGNOSIS, headline: hostile, componentLabel: hostile },
      explanation: {
        summary: hostile,
        fixSteps: [hostile, "<script>window.pwned=2</script>"],
        sources: [hostile],
        source: "LLM"
      }
    });
    expect(element.shadowRoot.querySelector("img")).toBeNull();
    expect(element.shadowRoot.querySelector("script")).toBeNull();
    expect(q(element, "headline").textContent).toBe(hostile);
    expect(q(element, "summary").textContent).toBe(hostile);
    expect(window.pwned).toBeUndefined();
  });
});

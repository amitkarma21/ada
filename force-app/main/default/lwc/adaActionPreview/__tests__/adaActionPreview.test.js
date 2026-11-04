import { createElement } from "lwc";
import AdaActionPreview from "c/adaActionPreview";

const PROPOSAL = {
  title: "ADA: UNKNOWN",
  payloadJson: '{"title":"ADA: UNKNOWN"}',
  notes: ""
};

function build(props = {}) {
  const element = createElement("c-ada-action-preview", {
    is: AdaActionPreview
  });
  Object.assign(element, props);
  document.body.appendChild(element);
  return element;
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function q(element, id) {
  return element.shadowRoot.querySelector(`[data-id="${id}"]`);
}

async function typeNotes(element, text) {
  const input = q(element, "notes");
  input.value = text;
  input.dispatchEvent(new CustomEvent("change", { detail: { value: text } }));
  await flush();
}

describe("c-ada-action-preview", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders nothing without a proposal", () => {
    const element = build();
    expect(q(element, "confirm")).toBeNull();
    expect(element.shadowRoot.querySelector("section")).toBeNull();
  });

  it("shows the exact report and says nothing has been sent", () => {
    const element = build({ proposal: PROPOSAL });
    expect(q(element, "proposal-title").textContent).toBe("ADA: UNKNOWN");
    expect(q(element, "payload").textContent).toBe('{"title":"ADA: UNKNOWN"}');
    expect(q(element, "nothing-sent").textContent).toContain("Nothing");
    expect(q(element, "confirm").label).toBe("Send to my admin team");
    expect(q(element, "confirm").disabled).toBe(false);
    expect(q(element, "result")).toBeNull();
  });

  it("labels the region and the notes box", () => {
    const element = build({ proposal: PROPOSAL });
    expect(
      element.shadowRoot.querySelector("section").getAttribute("aria-label")
    ).toBe("Report preview");
    expect(q(element, "notes").label).toBe("Add anything that would help");
    expect(Number(q(element, "notes").maxLength)).toBe(2000);
  });

  it("confirms with the notes the preview was built from", async () => {
    const element = build({ proposal: { ...PROPOSAL, notes: "Saved twice." } });
    const handler = jest.fn();
    element.addEventListener("confirm", handler);
    expect(q(element, "notes").value).toBe("Saved twice.");
    q(element, "confirm").click();
    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler.mock.calls[0][0].detail).toEqual({ notes: "Saved twice." });
  });

  it("will not confirm edited notes until the preview is refreshed", async () => {
    const element = build({ proposal: PROPOSAL });
    const confirmHandler = jest.fn();
    const refreshHandler = jest.fn();
    element.addEventListener("confirm", confirmHandler);
    element.addEventListener("previewrefresh", refreshHandler);
    await typeNotes(element, "It started today.");
    expect(q(element, "confirm").disabled).toBe(true);
    expect(q(element, "refresh").disabled).toBe(false);
    q(element, "confirm").click();
    expect(confirmHandler).not.toHaveBeenCalled();
    q(element, "refresh").click();
    expect(refreshHandler).toHaveBeenCalledTimes(1);
    expect(refreshHandler.mock.calls[0][0].detail).toEqual({
      notes: "It started today."
    });
  });

  it("allows confirming again once the refreshed proposal matches the notes", async () => {
    const element = build({ proposal: PROPOSAL });
    await typeNotes(element, "It started today.");
    element.proposal = { ...PROPOSAL, notes: "It started today." };
    await flush();
    expect(q(element, "confirm").disabled).toBe(false);
    expect(q(element, "refresh").disabled).toBe(true);
  });

  it("disables everything while busy", async () => {
    const element = build({ proposal: PROPOSAL, busy: true });
    await typeNotes(element, "More detail.");
    expect(q(element, "confirm").disabled).toBe(true);
    expect(q(element, "refresh").disabled).toBe(true);
  });

  it("shows a success message and locks the form so it cannot be sent twice", async () => {
    const element = build({ proposal: PROPOSAL });
    element.result = {
      success: true,
      status: "Success",
      message: "Your admin team was emailed the report."
    };
    await flush();
    const result = q(element, "result");
    expect(result.textContent).toContain("Your admin team was emailed");
    expect(result.getAttribute("role")).toBe("status");
    expect(q(element, "confirm")).toBeNull();
    expect(q(element, "notes").disabled).toBe(true);
    expect(q(element, "nothing-sent")).toBeNull();
  });

  it("says so when the report had already been sent", async () => {
    const element = build({
      proposal: PROPOSAL,
      result: {
        success: true,
        alreadySent: true,
        message: "This report was already sent. Your admin team has it."
      }
    });
    expect(q(element, "result").textContent).toContain("already sent");
    expect(q(element, "confirm")).toBeNull();
  });

  it("shows a failure as an alert and lets the person try again", async () => {
    const element = build({
      proposal: PROPOSAL,
      result: {
        success: false,
        status: "Failed",
        message: "The report could not be sent. Try again."
      }
    });
    const alert = q(element, "result");
    expect(alert.getAttribute("role")).toBe("alert");
    expect(alert.textContent).toContain("could not be sent");
    expect(q(element, "confirm").disabled).toBe(false);
    const handler = jest.fn();
    element.addEventListener("confirm", handler);
    q(element, "confirm").click();
    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("shows a blocked report as an alert and still allows a retry", () => {
    const element = build({
      proposal: PROPOSAL,
      result: {
        success: false,
        status: "Blocked",
        message: "The report held personal data (EMAIL), so nothing was sent."
      }
    });
    expect(q(element, "result").getAttribute("role")).toBe("alert");
    expect(q(element, "result").textContent).toContain("nothing was sent");
  });

  it("renders markup from the server as plain text", () => {
    const hostile = '<img src=x onerror="window.pwned=1">';
    const element = build({
      proposal: { title: hostile, payloadJson: hostile, notes: "" },
      result: { success: false, message: hostile }
    });
    expect(element.shadowRoot.querySelector("img")).toBeNull();
    expect(q(element, "proposal-title").textContent).toBe(hostile);
    expect(q(element, "payload").textContent).toBe(hostile);
    expect(q(element, "result").textContent).toBe(hostile);
    expect(window.pwned).toBeUndefined();
  });
});

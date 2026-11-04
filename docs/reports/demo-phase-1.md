# Phase 1 demo checklist (dev org `ada-dev`)

Run `scripts/setup-dev-org.sh` first (deploys, assigns permission sets, seeds). Open the
**ADA Demo** app and click **ADA Help** in the utility bar. Test as a user with `ADA_User`
(not only as the admin).

## Setup
- [ ] The utility bar shows **ADA Help** and opens the panel (no To Do List).
- [ ] The panel has a labelled box "Paste the error message" and a disabled **Diagnose** button.
- [ ] Typing spaces only keeps **Diagnose** disabled; typing text enables it.

## Confident answers (open an Opportunity first so the record id is passed)
- [ ] Paste `Close date cannot be in the past for an open opportunity.` Press **Diagnose**.
  Status says "Looking into it…", then the card reads "This looks like a validation rule: ...",
  shows a confidence figure, the rule name, an explanation and numbered fix steps.
- [ ] Keyboard focus lands on the result heading; Tab reaches the feedback buttons, Enter and
  Space activate them.
- [ ] The source line says "AI model" (LLM on) or "Standard guidance" (Template).
- [ ] Press **Yes, solved**: the buttons are replaced by "Thanks for letting us know." Check
  `ADA_Action_Log__c`: one `Feedback` row, `Solved`.
- [ ] Repeat with `Opportunities over 100,000 need a description.` and, on a Case,
  `Please choose a reason before closing the case.`
- [ ] Repeat with the flow, trigger and duplicate messages from `test-data/golden-errors.json`.

## Low confidence
- [ ] Paste `The quarterly forecast must be approved before Friday.` The card says "I'm not
  sure what's blocking you.", shows no steps and no feedback buttons.
- [ ] Press **Prepare a report for my admin**: a preview with a title and the exact payload
  appears, with "Nothing has been sent." Check the log: one `Propose` row, no external call.

## Errors and reset
- [ ] With the LLM switched off (Template setting), a confident error still gets steps.
- [ ] A stale or failed call shows a red message (screen reader announces it) and the pasted
  text stays in the box.
- [ ] **Start over** clears the box, the card and any message.

## Safety
- [ ] Paste `<img src=x onerror=alert(1)>`: it is shown as plain text, no alert fires.
- [ ] An admin (no `ADA_User`) cannot see the panel's data; a user cannot read another user's
  log rows.

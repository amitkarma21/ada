trigger ADA_Demo_CaseTrigger on Case(before insert, before update) {
  for (Case c : Trigger.new) {
    if (c.SuppliedEmail != null && c.Origin == null) {
      c.addError('Cases that arrive from the web must have an Origin.');
    }
  }
}

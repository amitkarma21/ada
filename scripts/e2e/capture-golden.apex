// Triggers each demo error with partial-success DML and prints the platform's exact wording.
// One line per case: ADA_GOLDEN|{"id":...,"object":...,"statusCode":...,"message":...}
// Run through scripts/e2e/capture-golden.mjs. Only the first error of each save is kept.
private static void emit(String id, String objectName, List<Database.Error> errors) {
  Map<String, Object> row = new Map<String, Object>{
    'id' => id,
    'object' => objectName,
    'statusCode' => errors.isEmpty() ? 'NONE' : String.valueOf(errors[0].getStatusCode()),
    'message' => errors.isEmpty() ? '' : errors[0].getMessage()
  };
  System.debug(LoggingLevel.ERROR, 'ADA_GOLDEN|' + JSON.serialize(row));
}

Date nextMonth = Date.today().addDays(30);

emit(
  'opp-closedate-past',
  'Opportunity',
  Database.insert(
      new Opportunity(
        Name = 'ADA golden',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(-5)
      ),
      false
    )
    .getErrors()
);

emit(
  'opp-large-deal-description',
  'Opportunity',
  Database.insert(
      new Opportunity(
        Name = 'ADA golden',
        StageName = 'Prospecting',
        CloseDate = nextMonth,
        Amount = 150000
      ),
      false
    )
    .getErrors()
);

emit(
  'case-close-reason',
  'Case',
  Database.insert(new Case(Subject = 'ADA golden', Origin = 'Phone', Status = 'Closed'), false)
    .getErrors()
);

emit(
  'case-flow-escalated-priority',
  'Case',
  Database.insert(
      new Case(Subject = 'ADA golden', Origin = 'Phone', IsEscalated = true, Priority = 'Low'),
      false
    )
    .getErrors()
);

emit(
  'case-trigger-web-origin',
  'Case',
  Database.insert(new Case(Subject = 'ADA golden', SuppliedEmail = 'web.user@example.com'), false)
    .getErrors()
);

Account first = new Account(Name = 'ADA golden duplicate');
insert first;
emit(
  'account-duplicate',
  'Account',
  Database.insert(new Account(Name = 'ADA golden duplicate'), false).getErrors()
);
delete first;

emit(
  'opp-required-field',
  'Opportunity',
  Database.insert(new Opportunity(Name = 'ADA golden'), false).getErrors()
);

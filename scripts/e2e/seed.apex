// Demo and canary seed data. Canary values come from test-data/canaries.json and must never
// appear in an outbound request body (see the egress canary test, step 1.5).
delete [SELECT Id FROM Opportunity WHERE Name = 'CANARY-OPP-4K9X'];
delete [SELECT Id FROM Case WHERE Subject = 'CANARY-CASE-T6W1'];
delete [SELECT Id FROM Contact WHERE Email = 'canary.person.5r8n@example.com'];
delete [SELECT Id FROM Account WHERE Name = 'CANARY-ACCT-7Q2Z'];

Account acct = new Account(Name = 'CANARY-ACCT-7Q2Z');
insert acct;

insert new Contact(
  AccountId = acct.Id,
  LastName = 'Canary',
  Email = 'canary.person.5r8n@example.com'
);

insert new Opportunity(
  AccountId = acct.Id,
  Name = 'CANARY-OPP-4K9X',
  StageName = 'Prospecting',
  CloseDate = Date.today().addDays(30),
  Amount = 987654.32,
  Description = 'CANARY-DESC-M3P8',
  ADA_Demo_Internal_Notes__c = 'CANARY-NOTE-H5J2'
);

insert new Case(
  AccountId = acct.Id,
  Subject = 'CANARY-CASE-T6W1',
  Origin = 'Phone',
  Status = 'New',
  Priority = 'Medium'
);

System.debug(LoggingLevel.ERROR, 'ADA_SEED_OK|done');

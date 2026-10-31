@IsTest
private class ADA_EgressCanaryTest {
  private static final String ACCOUNT_NAME = 'CANARY-ACCT-7Q2Z';
  private static final String OPPORTUNITY_NAME = 'CANARY-OPP-4K9X';
  private static final String DESCRIPTION = 'CANARY-DESC-M3P8';
  private static final String CASE_SUBJECT = 'CANARY-CASE-T6W1';
  private static final String NOTE = 'CANARY-NOTE-H5J2';
  private static final String EMAIL = 'canary.person.5r8n@example.com';
  private static final String AMOUNT = '987654.32';

  private static final List<String> CANARIES = new List<String>{
    ACCOUNT_NAME,
    OPPORTUNITY_NAME,
    DESCRIPTION,
    CASE_SUBJECT,
    NOTE,
    EMAIL,
    AMOUNT
  };

  private class Recorder implements HttpCalloutMock {
    public List<String> requests = new List<String>();

    public HttpResponse respond(HttpRequest request) {
      requests.add(
        request.getMethod() +
          ' ' +
          request.getEndpoint() +
          '\n' +
          request.getBody()
      );
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody('{"records":[],"done":true}');
      return response;
    }
  }

  private static void seedCanaryRecords() {
    Account account = new Account(Name = ACCOUNT_NAME);
    insert account;
    insert new Contact(
      AccountId = account.Id,
      FirstName = 'Canary',
      LastName = 'Person',
      Email = EMAIL
    );
    insert new Opportunity(
      AccountId = account.Id,
      Name = OPPORTUNITY_NAME,
      Description = DESCRIPTION,
      Amount = Decimal.valueOf(AMOUNT),
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    Case seeded = new Case(
      AccountId = account.Id,
      Subject = CASE_SUBJECT,
      Origin = 'Phone'
    );
    insert seeded;
    insert new CaseComment(ParentId = seeded.Id, CommentBody = NOTE);
  }

  private static ADA_MatcherTestSupport.FakeStore store() {
    return new ADA_MatcherTestSupport.FakeStore()
      .add(
        ADA_MatcherTestSupport.messageRow(
          'ValidationRule',
          'Opportunity',
          'Large_Deal_Rule',
          'Opportunities over 100,000 need a description.'
        )
      )
      .add(
        ADA_MatcherTestSupport.messageRow(
          'Flow',
          'Case',
          'Escalation_Flow',
          'Cannot escalate {!Case.Subject} without a priority.'
        )
      );
  }

  private static void send(String body) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:ADA_Llm/chat/completions');
    request.setMethod('POST');
    request.setBody(body);
    ADA_HttpGateway.execute(request);
  }

  private static void assertNoCanary(Recorder recorder) {
    Assert.isFalse(
      recorder.requests.isEmpty(),
      'Nothing was sent, so the test proves nothing'
    );
    for (String sent : recorder.requests) {
      for (String canary : CANARIES) {
        Assert.isFalse(
          sent.contains(canary),
          'Canary ' + canary + ' left the org in: ' + sent
        );
      }
    }
  }

  // Each later step adds its own flow here: explain (1.6), propose (1.9), confirm (1.10).
  @IsTest
  static void diagnoseThenExplainSendsNoRecordValue() {
    seedCanaryRecords();
    Recorder recorder = new Recorder();
    Test.setMock(HttpCalloutMock.class, recorder);

    ADA_Diagnosis rule = ADA_DiagnosisService.diagnose(
      'Opportunity',
      'Opportunities over 100,000 need a description.',
      store()
    );
    ADA_Diagnosis flow = ADA_DiagnosisService.diagnose(
      'Case',
      'Cannot escalate ' + CASE_SUBJECT + ' without a priority.',
      store()
    );
    Assert.areEqual(ADA_ErrorType.VALIDATION_RULE, rule.errorType);
    Assert.areEqual(ADA_ErrorType.FLOW, flow.errorType);

    Test.startTest();
    for (ADA_Diagnosis diagnosis : new List<ADA_Diagnosis>{ rule, flow }) {
      ADA_PayloadBuilder.Extras extras = new ADA_PayloadBuilder.Extras();
      extras.objectLabel = diagnosis.objectApiName;
      extras.userQuestion =
        'Why can\'t I save ' +
        ACCOUNT_NAME +
        '? Reply to ' +
        EMAIL +
        ' or ring 0412 345 678.';
      send(
        ADA_PayloadBuilder.toJson(ADA_PayloadBuilder.forLlm(diagnosis, extras))
      );
    }
    Test.stopTest();

    assertNoCanary(recorder);
    String first = recorder.requests[0];
    Assert.isTrue(
      first.contains('[NAME]'),
      'The account name should have been scrubbed'
    );
    Assert.isTrue(first.contains('[EMAIL]'));
    Assert.isTrue(first.contains('[PHONE]'));
    Assert.isTrue(first.contains('Large_Deal_Rule'));
  }

  @IsTest
  static void aBodyBuiltByHandThatHoldsPersonalDataIsBlockedAtTheGateway() {
    seedCanaryRecords();
    Recorder recorder = new Recorder();
    Test.setMock(HttpCalloutMock.class, recorder);
    Test.startTest();
    try {
      send('{"note":"Reply to ' + EMAIL + '"}');
      Assert.fail('The gateway should have blocked this body');
    } catch (ADA_BlockedRequestException e) {
      Assert.isTrue(e.kinds.contains('EMAIL'));
      Assert.isFalse(e.getMessage().contains(EMAIL));
    }
    Test.stopTest();
    Assert.isTrue(
      recorder.requests.isEmpty(),
      'A blocked body must never be sent'
    );
  }
}

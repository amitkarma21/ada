@IsTest
private class ADA_EmailTargetTest {
  private static final String ADMIN = 'bugs.inbox@example.com';

  private class StubSender implements ADA_EmailTarget.Sender {
    public List<Messaging.SingleEmailMessage> sent = new List<Messaging.SingleEmailMessage>();
    public String code;
    public Boolean throwLimit = false;

    public String deliver(Messaging.SingleEmailMessage message) {
      if (throwLimit) {
        throw new EmailException(
          'SINGLE_EMAIL_LIMIT_EXCEEDED: Single email limit exceeded.'
        );
      }
      sent.add(message);
      return code;
    }
  }

  private static ADA_Setting__mdt setting(String address) {
    return new ADA_Setting__mdt(Bug_Report_Email__c = address);
  }

  private static ADA_EmailTarget target() {
    return new ADA_EmailTarget(setting(ADMIN));
  }

  private static String rawPayload(
    String title,
    String description,
    String tags
  ) {
    ADA_PayloadBuilder.WorkItemBody body = new ADA_PayloadBuilder.WorkItemBody();
    body.title = title;
    body.description = description;
    body.tags = tags;
    return ADA_PayloadBuilder.toJson(body);
  }

  private static StubSender stub() {
    StubSender stub = new StubSender();
    ADA_EmailTarget.sender = stub;
    return stub;
  }

  @IsTest
  static void aRealSendUsesOneEmailInvocationAndReportsSuccess() {
    Test.startTest();
    ADA_ActionResult result = target()
      .submit('key-1', ADA_AdoTestSupport.payload('The save keeps failing.'));
    Integer invocations = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.isTrue(result.success, result.message);
    Assert.areEqual('Success', result.status);
    Assert.areEqual('Email', result.target);
    Assert.areEqual(1, invocations);
    Assert.isNull(result.externalUrl);
    Assert.isTrue(result.message.contains('emailed'), result.message);
  }

  @IsTest
  static void theMessageGoesOnlyToTheConfiguredAddressAsPlainText() {
    StubSender stub = stub();
    ADA_ActionResult result = target()
      .submit('key-1', ADA_AdoTestSupport.payload('Please look at this.'));

    Assert.isTrue(result.success, result.message);
    Assert.areEqual(1, stub.sent.size());
    Messaging.SingleEmailMessage message = stub.sent[0];
    Assert.areEqual(new List<String>{ ADMIN }, message.getToAddresses());
    Assert.isTrue(
      message.getCcAddresses() == null || message.getCcAddresses().isEmpty()
    );
    Assert.isTrue(
      message.getBccAddresses() == null || message.getBccAddresses().isEmpty()
    );
    Assert.isNull(message.getHtmlBody());
    Assert.isFalse(message.getSaveAsActivity());
    Assert.isTrue(
      message.getSubject().startsWith('ADA: '),
      message.getSubject()
    );
    String text = message.getPlainTextBody();
    Assert.isTrue(text.contains('Error type:'), text);
    Assert.isTrue(text.contains('Please look at this.'), text);
    Assert.isTrue(text.contains('ADA-rule:' + ADA_AdoTestSupport.RULE), text);
  }

  @IsTest
  static void lineBreaksInTheTitleCannotAddHeaders() {
    StubSender stub = stub();
    ADA_ActionResult result = target()
      .submit(
        'key-1',
        rawPayload(
          'ADA: Oops\r\nBcc: someone\nSubject: other',
          'Error type: APEX',
          'ADA'
        )
      );

    Assert.isTrue(result.success, result.message);
    Messaging.SingleEmailMessage message = stub.sent[0];
    Assert.isFalse(message.getSubject().contains('\n'));
    Assert.isFalse(message.getSubject().contains('\r'));
    Assert.isTrue(
      message.getBccAddresses() == null || message.getBccAddresses().isEmpty()
    );
  }

  @IsTest
  static void aLongTitleIsClippedForTheSubject() {
    StubSender stub = stub();
    target()
      .submit(
        'key-1',
        rawPayload('ADA: ' + 'x'.repeat(500), 'Error type: APEX', 'ADA')
      );
    Assert.isTrue(stub.sent[0].getSubject().length() <= 200);
  }

  @IsTest
  static void withoutAConfiguredAddressNothingIsSent() {
    StubSender stub = stub();
    for (
      ADA_Setting__mdt unset : new List<ADA_Setting__mdt>{
        null,
        setting(null),
        setting('   ')
      }
    ) {
      ADA_ActionResult result = new ADA_EmailTarget(unset)
        .submit('key-1', ADA_AdoTestSupport.payload(null));
      Assert.isFalse(result.success);
      Assert.areEqual('Failed', result.status);
      Assert.isTrue(result.message.contains('admin'), result.message);
    }
    Assert.isTrue(stub.sent.isEmpty());
  }

  @IsTest
  static void anAddressThatIsNotASingleMailboxIsRefused() {
    StubSender stub = stub();
    for (
      String bad : new List<String>{
        'not-an-address',
        'a@b',
        'one@example.com,two@example.com',
        'one@example.com two@example.com',
        'one@example.com\nBcc: two@example.com'
      }
    ) {
      ADA_ActionResult result = new ADA_EmailTarget(setting(bad))
        .submit('key-1', ADA_AdoTestSupport.payload(null));
      Assert.areEqual('Failed', result.status, bad);
    }
    Assert.isTrue(stub.sent.isEmpty());
  }

  @IsTest
  static void badInputSendsNothing() {
    StubSender stub = stub();
    Assert.areEqual(
      'Failed',
      target().submit(null, ADA_AdoTestSupport.payload(null)).status
    );
    Assert.areEqual(
      'Failed',
      target().submit(' ', ADA_AdoTestSupport.payload(null)).status
    );
    Assert.areEqual('Failed', target().submit('key-1', null).status);
    Assert.areEqual('Failed', target().submit('key-1', 'not json').status);
    Assert.areEqual('Failed', target().submit('key-1', '{"title":"t"}').status);
    Assert.areEqual(
      'Failed',
      target().submit('key-1', rawPayload('t', 'd', ' ')).status
    );
    Assert.isTrue(stub.sent.isEmpty());
  }

  @IsTest
  static void aBodyThatHoldsPersonalDataIsBlockedBeforeSending() {
    StubSender stub = stub();
    ADA_ActionResult result = target()
      .submit(
        'key-1',
        rawPayload(
          'ADA: Problem',
          'Error type: APEX\nReply to casey.person@example.com',
          'ADA'
        )
      );

    Assert.isFalse(result.success);
    Assert.areEqual('Blocked', result.status);
    Assert.isFalse(result.message.contains('casey.person@example.com'));
    Assert.isTrue(stub.sent.isEmpty());
  }

  @IsTest
  static void personalDataInTheTitleIsBlockedToo() {
    StubSender stub = stub();
    ADA_ActionResult result = target()
      .submit(
        'key-1',
        rawPayload('ADA: call 0412 345 678', 'Error type: APEX', 'ADA')
      );
    Assert.areEqual('Blocked', result.status);
    Assert.isTrue(stub.sent.isEmpty());
  }

  @IsTest
  static void aFailedSendGivesAPlainMessageAndNoException() {
    StubSender stub = stub();
    stub.code = 'INVALID_EMAIL_ADDRESS';
    ADA_ActionResult invalid = target()
      .submit('key-1', ADA_AdoTestSupport.payload(null));
    Assert.areEqual('Failed', invalid.status);
    Assert.isTrue(invalid.message.contains('admin'), invalid.message);

    stub.code = 'SOMETHING_ELSE';
    ADA_ActionResult other = target()
      .submit('key-1', ADA_AdoTestSupport.payload(null));
    Assert.areEqual('Failed', other.status);
    Assert.isTrue(other.message.contains('could not be sent'), other.message);
  }

  @IsTest
  static void theDailyLimitGivesAPlainMessage() {
    StubSender stub = stub();
    stub.throwLimit = true;
    ADA_ActionResult result = target()
      .submit('key-1', ADA_AdoTestSupport.payload(null));
    Assert.areEqual('Failed', result.status);
    Assert.isTrue(result.message.contains('limit'), result.message);
    Assert.isFalse(result.message.contains('SINGLE_EMAIL_LIMIT_EXCEEDED'));
  }

  @IsTest
  static void aGeneratedSessionKeyNeverTripsTheGate() {
    StubSender stub = stub();
    for (Integer i = 0; i < 25; i++) {
      ADA_PayloadBuilder.WorkItemBody body = ADA_PayloadBuilder.forWorkItem(
        ADA_AdoTestSupport.diagnosis(),
        ADA_AgentSession.newKey(),
        null
      );
      ADA_ActionResult result = target()
        .submit('key-' + i, ADA_PayloadBuilder.toJson(body));
      Assert.areEqual('Success', result.status, result.message);
    }
    Assert.areEqual(25, stub.sent.size());
  }

  @IsTest
  static void targetName() {
    Assert.areEqual('Email', target().targetName());
  }
}

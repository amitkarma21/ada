@IsTest
private class ADA_AgentControllerTest {
  private static final String OPPORTUNITY_ID = '006000000000001';
  private static final String RULE_MESSAGE = 'Close date cannot be in the past for an open opportunity.';
  private static final String UNMATCHED = 'Something odd happened that no rule explains.';

  @TestSetup
  static void setup() {
    ADA_IndexTestSupport.createUser('adagt1', 'ADA_User');
    ADA_IndexTestSupport.createUser('adagt2', 'ADA_User');
    ADA_IndexTestSupport.createUser('adagta', 'ADA_Admin');
    System.runAs(new User(Id = UserInfo.getUserId())) {
      ADA_Metadata_Index__c rule = ADA_MatcherTestSupport.messageRow(
        'ValidationRule',
        'Opportunity',
        'Close_Date_Rule',
        RULE_MESSAGE
      );
      rule.Formula_Masked__c = 'AND(NOT(IsClosed), CloseDate < TODAY())';
      rule.Description__c = 'An open deal needs a future date.';
      rule.Field_Api_Names__c = 'CloseDate,IsClosed';
      rule.Source_Last_Modified__c = Datetime.newInstanceGmt(2026, 3, 1);
      insert rule;
    }
  }

  private static User userByAlias(String alias) {
    return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1];
  }

  private static String diagnoseAs(String alias) {
    String key;
    System.runAs(userByAlias(alias)) {
      key = ADA_AgentController.diagnose(RULE_MESSAGE, OPPORTUNITY_ID)
        .sessionKey;
    }
    return key;
  }

  private class RecordingSender implements ADA_EmailTarget.Sender {
    public List<Messaging.SingleEmailMessage> sent = new List<Messaging.SingleEmailMessage>();

    public String deliver(Messaging.SingleEmailMessage message) {
      sent.add(message);
      return null;
    }
  }

  private class FixedTarget implements ADA_IActionTarget {
    public Integer calls = 0;
    private final ADA_ActionResult result;

    public FixedTarget(ADA_ActionResult result) {
      this.result = result;
    }

    public String targetName() {
      return 'Email';
    }

    public ADA_ActionResult submit(String idempotencyKey, String payloadJson) {
      calls++;
      return result;
    }
  }

  private static RecordingSender emailTo(String address) {
    RecordingSender sender = new RecordingSender();
    ADA_EmailTarget.sender = sender;
    ADA_AgentController.targetOverride = new ADA_EmailTarget(
      new ADA_Setting__mdt(Bug_Report_Email__c = address)
    );
    return sender;
  }

  private static List<ADA_Action_Log__c> logs(String step) {
    return [
      SELECT
        Step__c,
        Target_System__c,
        Status__c,
        Payload_Sent__c,
        Result__c,
        Feedback__c,
        Error_Type__c,
        Component_Api_Name__c,
        Confidence__c,
        Session_Key__c
      FROM ADA_Action_Log__c
      WHERE Step__c = :step
    ];
  }

  @IsTest
  static void theFullPathRunsWithMocksAndLogsEveryStep() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    String key;
    System.runAs(userByAlias('adagt1')) {
      ADA_AgentController.DiagnosisView view = ADA_AgentController.diagnose(
        RULE_MESSAGE,
        OPPORTUNITY_ID
      );
      key = view.sessionKey;
      Assert.isTrue(Pattern.matches('[0-9a-f]{32}', key));
      Assert.areEqual('VALIDATION_RULE', view.errorType);
      Assert.isTrue(view.confident);
      Assert.isTrue(view.confidence >= 0.8);
      Assert.areEqual('Close_Date_Rule', view.componentApiName);
      Assert.areEqual('Opportunity', view.objectApiName);
      Assert.areEqual(
        new List<String>{ 'EXPLAIN', 'RAISE_BUG' },
        view.allowedActions
      );
      Assert.areEqual(0, mock.calls, 'diagnose must not call out');
    }
    // Each LWC call is its own transaction; startTest separates the diagnose DML from
    // the callout the way the platform does.
    Test.startTest();
    System.runAs(userByAlias('adagt1')) {
      ADA_AgentController.ExplanationView explanation = ADA_AgentController.explain(
        key,
        null
      );
      Assert.areEqual(
        'LLM',
        explanation.source,
        [SELECT Result__c FROM ADA_Action_Log__c WHERE Step__c = 'Explain'][0]
        .Result__c
      );
      Assert.isFalse(explanation.usedFallback);
      Assert.isFalse(explanation.fixSteps.isEmpty());
      Assert.areEqual(1, mock.calls);

      ADA_AgentController.ProposalView proposal = ADA_AgentController.proposeAction(
        key,
        'RAISE_BUG',
        null
      );
      Assert.areEqual('RAISE_BUG', proposal.actionType);
      Assert.isTrue(proposal.requiresConfirmation);
      Assert.isTrue(proposal.payloadJson.contains('ADA-rule:Close_Date_Rule'));
      Assert.areEqual(1, mock.calls, 'propose must not call out');

      ADA_AgentController.recordFeedback(key, true);
    }
    Test.stopTest();

    Assert.areEqual(4, [SELECT COUNT() FROM ADA_Action_Log__c]);
    ADA_Action_Log__c diagnose = logs('Diagnose')[0];
    Assert.areEqual(key, diagnose.Session_Key__c);
    Assert.areEqual('VALIDATION_RULE', diagnose.Error_Type__c);
    Assert.areEqual('Close_Date_Rule', diagnose.Component_Api_Name__c);
    Assert.isFalse(diagnose.Result__c.contains('Close date cannot'));
    ADA_Action_Log__c explain = logs('Explain')[0];
    Assert.areEqual('LLM', explain.Target_System__c);
    Assert.areEqual('Success', explain.Status__c);
    Assert.areEqual(
      mock.requests[0].getBody(),
      explain.Payload_Sent__c,
      'the log must hold the exact body that was sent'
    );
    Assert.isTrue(explain.Payload_Sent__c.contains('VALIDATION_RULE'));
    ADA_Action_Log__c propose = logs('Propose')[0];
    Assert.areEqual('None', propose.Target_System__c);
    Assert.isNull(propose.Payload_Sent__c);
    Assert.areEqual('Solved', logs('Feedback')[0].Feedback__c);
    for (ADA_Action_Log__c row : [
      SELECT Session_Key__c
      FROM ADA_Action_Log__c
    ]) {
      Assert.areEqual(key, row.Session_Key__c);
    }
  }

  @IsTest
  static void aSecondUserCannotUseTheSession() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    String key;
    System.runAs(userByAlias('adagt1')) {
      key = ADA_AgentController.diagnose(RULE_MESSAGE, OPPORTUNITY_ID)
        .sessionKey;
    }
    for (String alias : new List<String>{ 'adagt2', 'adagta' }) {
      System.runAs(userByAlias(alias)) {
        assertSessionRejected(key);
      }
    }
    Assert.areEqual(0, mock.calls);
    Assert.areEqual(1, [SELECT COUNT() FROM ADA_Action_Log__c]);
  }

  private static void assertSessionRejected(String key) {
    try {
      ADA_AgentController.explain(key, null);
      Assert.fail('explain must reject the session');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Session not found'));
    }
    try {
      ADA_AgentController.proposeAction(key, 'RAISE_BUG', null);
      Assert.fail('propose must reject the session');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Session not found'));
    }
    try {
      ADA_AgentController.confirmAction(key, 'RAISE_BUG', null);
      Assert.fail('confirm must reject the session');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Session not found'));
    }
    try {
      ADA_AgentController.recordFeedback(key, true);
      Assert.fail('feedback must reject the session');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Session not found'));
    }
  }

  @IsTest
  static void aMadeUpKeyIsRejected() {
    System.runAs(userByAlias('adagt1')) {
      assertSessionRejected('0123456789abcdef0123456789abcdef');
      assertSessionRejected(null);
    }
  }

  @IsTest
  static void lowConfidenceSaysNotSureAndOffersOnlyRaiseBug() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    System.runAs(userByAlias('adagt1')) {
      ADA_AgentController.DiagnosisView view = ADA_AgentController.diagnose(
        UNMATCHED,
        OPPORTUNITY_ID
      );
      Assert.areEqual('UNKNOWN', view.errorType);
      Assert.isFalse(view.confident);
      Assert.areEqual(ADA_AgentController.NOT_SURE, view.headline);
      Assert.areEqual(new List<String>{ 'RAISE_BUG' }, view.allowedActions);

      ADA_AgentController.ExplanationView explanation = ADA_AgentController.explain(
        view.sessionKey,
        'Why is this happening?'
      );
      Assert.isTrue(
        explanation.summary.startsWith(ADA_AgentController.NOT_SURE)
      );
      Assert.isTrue(explanation.fixSteps.isEmpty());
      Assert.areEqual('None', explanation.source);
      Assert.areEqual(
        new List<String>{ 'RAISE_BUG' },
        explanation.allowedActions
      );

      ADA_AgentController.ProposalView proposal = ADA_AgentController.proposeAction(
        view.sessionKey,
        'RAISE_BUG',
        null
      );
      Assert.isTrue(proposal.payloadJson.contains('UNKNOWN'));
      try {
        ADA_AgentController.proposeAction(
          view.sessionKey,
          'REQUEST_ACCESS',
          null
        );
        Assert.fail('Only RAISE_BUG may be offered');
      } catch (AuraHandledException e) {
        Assert.isTrue(e.getMessage().contains('not available'));
      }
    }
    Assert.areEqual(0, mock.calls, 'no callout when not sure');
    ADA_Action_Log__c explain = logs('Explain')[0];
    Assert.areEqual('None', explain.Target_System__c);
    Assert.isNull(explain.Payload_Sent__c);
  }

  @IsTest
  static void aFailingModelFallsBackToTheTemplateAndIsLogged() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.status = 500;
    ADA_LlmTestSupport.useOpenAi();
    String key = diagnoseAs('adagt1');
    Test.startTest();
    System.runAs(userByAlias('adagt1')) {
      ADA_AgentController.ExplanationView explanation = ADA_AgentController.explain(
        key,
        null
      );
      Assert.areEqual(1, mock.calls, 'the model must have been called');
      Assert.areEqual('Template', explanation.source);
      Assert.isTrue(explanation.usedFallback);
      Assert.isFalse(explanation.fixSteps.isEmpty());
    }
    Test.stopTest();
    ADA_Action_Log__c explain = logs('Explain')[0];
    Assert.areEqual('Fallback', explain.Status__c);
    Assert.areEqual('LLM', explain.Target_System__c);
    Assert.isNotNull(explain.Payload_Sent__c);
    Assert.isNotNull(explain.Result__c);
    Assert.isFalse(explain.Result__c.contains('uncommitted'));
  }

  @IsTest
  static void templateModeMakesNoCalloutAndLogsNoTarget() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useProvider('Template', null);
    System.runAs(userByAlias('adagt1')) {
      String key = ADA_AgentController.diagnose(RULE_MESSAGE, OPPORTUNITY_ID)
        .sessionKey;
      ADA_AgentController.ExplanationView explanation = ADA_AgentController.explain(
        key,
        null
      );
      Assert.areEqual('Template', explanation.source);
      Assert.isFalse(explanation.usedFallback);
    }
    Assert.areEqual(0, mock.calls);
    ADA_Action_Log__c explain = logs('Explain')[0];
    Assert.areEqual('None', explain.Target_System__c);
    Assert.areEqual('Success', explain.Status__c);
    Assert.isNull(explain.Payload_Sent__c);
  }

  @IsTest
  static void theUsersQuestionIsScrubbedBeforeItLeaves() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    String key = diagnoseAs('adagt1');
    Test.startTest();
    System.runAs(userByAlias('adagt1')) {
      ADA_AgentController.explain(
        key,
        'Mail jane.doe@example.com.au or ring 0412 345 678 about this'
      );
    }
    Test.stopTest();
    Assert.areEqual(1, mock.calls);
    String body = mock.requests[0].getBody();
    Assert.isFalse(body.contains('jane.doe'));
    Assert.isFalse(body.contains('345 678'));
    Assert.isTrue(body.contains('[EMAIL]'));
    Assert.isFalse(logs('Explain')[0].Payload_Sent__c.contains('jane.doe'));
  }

  @IsTest
  static void theExtrasCarryTheMaskedFormulaAndLabels() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    String key = diagnoseAs('adagt1');
    Test.startTest();
    System.runAs(userByAlias('adagt1')) {
      ADA_AgentController.explain(key, null);
    }
    Test.stopTest();
    String sent = logs('Explain')[0].Payload_Sent__c;
    Assert.isTrue(sent.contains('CloseDate < TODAY()'), sent);
    Assert.isTrue(sent.contains('objectLabel'), sent);
    Assert.isTrue(sent.contains('ruleMessage'), sent);
    Assert.isTrue(sent.contains(RULE_MESSAGE), sent);
    Assert.isFalse(sent.contains('fieldLabelsByApiName'), sent);
  }

  @IsTest
  static void theTemplateAnswerUsesTheRuleItsMessageAndItsFields() {
    String key = diagnoseAs('adagt1');
    ADA_AgentController.ExplanationView view;
    Test.startTest();
    System.runAs(userByAlias('adagt1')) {
      view = ADA_AgentController.explain(key, null);
    }
    Test.stopTest();
    Assert.areEqual('Template', view.source);
    Assert.isTrue(view.summary.contains(RULE_MESSAGE), view.summary);
    Assert.isTrue(view.summary.contains('all of these are true'), view.summary);
    Assert.isTrue(
      view.summary.contains('Close Date is earlier than today'),
      view.summary
    );
    Assert.isTrue(
      view.fixSteps.contains('Set Close Date to today or a later date.'),
      String.join(view.fixSteps, ' | ')
    );
  }

  @IsTest
  static void feedbackCountsOncePerSession() {
    System.runAs(userByAlias('adagt1')) {
      String key = ADA_AgentController.diagnose(RULE_MESSAGE, OPPORTUNITY_ID)
        .sessionKey;
      ADA_AgentController.recordFeedback(key, false);
      ADA_AgentController.recordFeedback(key, true);
    }
    List<ADA_Action_Log__c> rows = logs('Feedback');
    Assert.areEqual(1, rows.size());
    Assert.areEqual('Not solved', rows[0].Feedback__c);
  }

  @IsTest
  static void aBlankErrorIsRejectedAndABadRecordIdStillDiagnoses() {
    System.runAs(userByAlias('adagt1')) {
      for (String blank : new List<String>{ null, '', '   ' }) {
        try {
          ADA_AgentController.diagnose(blank, OPPORTUNITY_ID);
          Assert.fail('A blank error must be rejected');
        } catch (AuraHandledException e) {
          Assert.isTrue(e.getMessage().contains('Paste the error'));
        }
      }
      for (String recordId : new List<String>{ null, '', 'garbage', '1234' }) {
        ADA_AgentController.DiagnosisView view = ADA_AgentController.diagnose(
          RULE_MESSAGE,
          recordId
        );
        Assert.isNotNull(view.sessionKey);
        Assert.isFalse(view.confident);
      }
      ADA_AgentController.DiagnosisView huge = ADA_AgentController.diagnose(
        RULE_MESSAGE + ' ' + 'x'.repeat(100000),
        OPPORTUNITY_ID
      );
      Assert.isNotNull(huge.sessionKey);
    }
  }

  @IsTest
  static void aPreviewShowsTheScrubbedNotesAndNothingIsSent() {
    RecordingSender sender = emailTo('bugs.inbox@example.com');
    System.runAs(userByAlias('adagt1')) {
      String key = ADA_AgentController.diagnose(UNMATCHED, OPPORTUNITY_ID)
        .sessionKey;
      ADA_AgentController.ProposalView preview = ADA_AgentController.proposeAction(
        key,
        'RAISE_BUG',
        'Mail casey.person@example.com or ring 0412 345 678.'
      );
      Assert.isTrue(preview.payloadJson.contains('[EMAIL]'));
      Assert.isTrue(preview.payloadJson.contains('[PHONE]'));
      Assert.isFalse(preview.payloadJson.contains('casey.person@example.com'));
      Assert.areEqual(
        'Mail casey.person@example.com or ring 0412 345 678.',
        preview.notes
      );
      ADA_AgentController.ProposalView plain = ADA_AgentController.proposeAction(
        key,
        'RAISE_BUG',
        null
      );
      Assert.areEqual('', plain.notes);
      Assert.isFalse(plain.payloadJson.contains('User notes'));
      ADA_AgentController.ProposalView big = ADA_AgentController.proposeAction(
        key,
        'RAISE_BUG',
        'n'.repeat(5000)
      );
      Assert.areEqual(2000, big.notes.length());
    }
    Assert.isTrue(sender.sent.isEmpty(), 'propose must not send');
  }

  @IsTest
  static void confirmSendsOneEmailLogsItAndASecondConfirmDoesNotResend() {
    RecordingSender sender = emailTo('bugs.inbox@example.com');
    String key = diagnoseAs('adagt1');
    String notes = 'Mail casey.person@example.com about this.';
    ADA_AgentController.ConfirmView first;
    ADA_AgentController.ConfirmView second;
    Test.startTest();
    System.runAs(userByAlias('adagt1')) {
      first = ADA_AgentController.confirmAction(key, 'RAISE_BUG', notes);
      second = ADA_AgentController.confirmAction(key, 'RAISE_BUG', notes);
    }
    Test.stopTest();

    Assert.isTrue(first.success, first.message);
    Assert.isFalse(first.alreadySent);
    Assert.isTrue(second.success);
    Assert.isTrue(second.alreadySent);
    Assert.areEqual(1, sender.sent.size());
    Assert.areEqual(
      new List<String>{ 'bugs.inbox@example.com' },
      sender.sent[0].getToAddresses()
    );
    Assert.isFalse(sender.sent[0].getPlainTextBody().contains('casey.person'));
    Assert.isTrue(sender.sent[0].getPlainTextBody().contains('[EMAIL]'));
    Assert.isTrue(sender.sent[0].getPlainTextBody().contains(key));

    List<ADA_Action_Log__c> rows = logs('Confirm');
    Assert.areEqual(1, rows.size());
    Assert.areEqual('Email', rows[0].Target_System__c);
    Assert.areEqual('Success', rows[0].Status__c);
    Assert.areEqual(key, rows[0].Session_Key__c);
    Assert.isTrue(rows[0].Payload_Sent__c.contains('ADA-rule:Close_Date_Rule'));
    Assert.isFalse(rows[0].Payload_Sent__c.contains('casey.person'));
  }

  @IsTest
  static void aFailedSendIsLoggedAndCanBeTriedAgain() {
    String key = diagnoseAs('adagt1');
    ADA_AgentController.ConfirmView failed;
    ADA_AgentController.ConfirmView retried;
    RecordingSender sender;
    Test.startTest();
    System.runAs(userByAlias('adagt1')) {
      emailTo(null);
      failed = ADA_AgentController.confirmAction(key, 'RAISE_BUG', null);
      sender = emailTo('bugs.inbox@example.com');
      retried = ADA_AgentController.confirmAction(key, 'RAISE_BUG', null);
    }
    Test.stopTest();

    Assert.isFalse(failed.success);
    Assert.areEqual('Failed', failed.status);
    Assert.isTrue(failed.message.contains('admin'), failed.message);
    Assert.isTrue(retried.success, retried.message);
    Assert.isFalse(retried.alreadySent);
    Assert.areEqual(1, sender.sent.size());
    Assert.areEqual(2, logs('Confirm').size());
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM ADA_Action_Log__c
        WHERE Step__c = 'Confirm' AND Status__c = 'Failed'
      ]
    );
  }

  @IsTest
  static void aBlockedSendKeepsPersonalDataOutOfTheLog() {
    FixedTarget target = new FixedTarget(
      ADA_ActionResult.blocked('Email', 'Not sent: personal data (EMAIL).')
    );
    ADA_AgentController.targetOverride = target;
    String key = diagnoseAs('adagt1');
    ADA_AgentController.ConfirmView view;
    System.runAs(userByAlias('adagt1')) {
      view = ADA_AgentController.confirmAction(key, 'RAISE_BUG', 'note');
    }
    Assert.isFalse(view.success);
    Assert.areEqual('Blocked', view.status);
    Assert.areEqual(1, target.calls);
    ADA_Action_Log__c row = logs('Confirm')[0];
    Assert.areEqual('Blocked', row.Status__c);
    Assert.isNull(row.Payload_Sent__c);
  }

  @IsTest
  static void confirmAcceptsOnlyRaiseBugAndOnlyOnYourOwnSession() {
    RecordingSender sender = emailTo('bugs.inbox@example.com');
    String key = diagnoseAs('adagt1');
    System.runAs(userByAlias('adagt1')) {
      for (
        String type : new List<String>{
          null,
          '',
          'raise_bug ',
          'REQUEST_ACCESS',
          'DELETE_EVERYTHING'
        }
      ) {
        try {
          ADA_AgentController.confirmAction(key, type, null);
          Assert.fail('Action should be rejected: ' + type);
        } catch (AuraHandledException e) {
          Assert.isTrue(e.getMessage().contains('not available'));
        }
      }
    }
    System.runAs(userByAlias('adagt2')) {
      try {
        ADA_AgentController.confirmAction(key, 'RAISE_BUG', null);
        Assert.fail('A second user must not confirm');
      } catch (AuraHandledException e) {
        Assert.isTrue(e.getMessage().contains('Session not found'));
      }
    }
    Assert.isTrue(sender.sent.isEmpty());
    Assert.areEqual(0, logs('Confirm').size());
  }

  @IsTest
  static void aNotSureSessionCanStillBeReported() {
    RecordingSender sender = emailTo('bugs.inbox@example.com');
    ADA_AgentController.ConfirmView view;
    Test.startTest();
    System.runAs(userByAlias('adagt1')) {
      String key = ADA_AgentController.diagnose(UNMATCHED, OPPORTUNITY_ID)
        .sessionKey;
      view = ADA_AgentController.confirmAction(key, 'RAISE_BUG', null);
    }
    Test.stopTest();
    Assert.isTrue(view.success, view.message);
    Assert.areEqual(1, sender.sent.size());
    Assert.isTrue(sender.sent[0].getSubject().contains('UNKNOWN'));
  }

  @IsTest
  static void aRawActionTypeIsValidatedOnTheServer() {
    System.runAs(userByAlias('adagt1')) {
      String key = ADA_AgentController.diagnose(RULE_MESSAGE, OPPORTUNITY_ID)
        .sessionKey;
      for (
        String type : new List<String>{
          null,
          '',
          'raise_bug ',
          'DELETE_EVERYTHING',
          'REQUEST_ACCESS'
        }
      ) {
        try {
          ADA_AgentController.proposeAction(key, type, null);
          Assert.fail('Action should be rejected: ' + type);
        } catch (AuraHandledException e) {
          Assert.isTrue(e.getMessage().contains('not available'));
        }
      }
    }
  }

  @IsTest
  static void theLogStatusReflectsBlockedAndFallback() {
    ADA_ExplanationService.Outcome blocked = new ADA_ExplanationService.Outcome();
    blocked.blockedKinds = new Set<String>{ 'EMAIL' };
    blocked.fallbackReason = 'blocked';
    Assert.areEqual('Blocked', ADA_AgentController.statusFor(blocked));
    ADA_ExplanationService.Outcome fallback = new ADA_ExplanationService.Outcome();
    fallback.fallbackReason = 'timeout';
    Assert.areEqual('Fallback', ADA_AgentController.statusFor(fallback));
    Assert.areEqual(
      'Success',
      ADA_AgentController.statusFor(new ADA_ExplanationService.Outcome())
    );
  }
}

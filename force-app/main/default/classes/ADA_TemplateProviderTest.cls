@IsTest
private class ADA_TemplateProviderTest {
  @IsTest
  static void everyErrorTypeGetsAnAnswerWithoutACallout() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_TemplateProvider provider = new ADA_TemplateProvider();
    for (ADA_ErrorType type : ADA_ErrorType.values()) {
      ADA_Explanation answer = provider.explain(
        new ADA_Diagnosis(type, 0.9),
        null
      );
      Assert.isFalse(String.isBlank(answer.summary), String.valueOf(type));
      Assert.isFalse(answer.fixSteps.isEmpty(), String.valueOf(type));
      Assert.isTrue(answer.fixSteps.size() <= 5);
      Assert.areEqual('Template', answer.source);
    }
    Assert.areEqual(0, mock.calls);
    Assert.isNull(provider.lastPayload());
  }

  @IsTest
  static void theComponentNameAndDescriptionAreUsed() {
    ADA_Explanation answer = new ADA_TemplateProvider()
      .explain(ADA_LlmTestSupport.diagnosis(), null);
    Assert.isTrue(answer.summary.contains('Close Date Rule'));
    Assert.isTrue(answer.summary.contains('An open deal needs a future date.'));
  }

  @IsTest
  static void anUnnamedComponentAndANullDiagnosisAreHandled() {
    ADA_Diagnosis bare = new ADA_Diagnosis(ADA_ErrorType.FLOW, 0.9);
    Assert.isFalse(
      new ADA_TemplateProvider().explain(bare, null).summary.contains('()')
    );
    bare.componentApiName = 'Escalate_Case';
    Assert.isTrue(
      new ADA_TemplateProvider()
        .explain(bare, null)
        .summary.contains('Escalate_Case')
    );
    Assert.isTrue(
      new ADA_TemplateProvider()
        .explain(null, null)
        .summary.contains('not sure')
    );
  }

  private static ADA_PayloadBuilder.Extras richExtras() {
    ADA_PayloadBuilder.Extras extras = ADA_LlmTestSupport.extras();
    extras.ruleMessage = 'Close date cannot be in the past for an open opportunity.';
    extras.fieldLabelsByApiName = new Map<String, String>{
      'CloseDate' => 'Close Date',
      'IsClosed' => 'Closed'
    };
    return extras;
  }

  @IsTest
  static void aValidationRuleIsExplainedFromItsMessageAndCondition() {
    ADA_Explanation answer = new ADA_TemplateProvider()
      .explain(ADA_LlmTestSupport.diagnosis(), richExtras());
    Assert.isTrue(
      answer.summary.contains(
        'Close date cannot be in the past for an open opportunity.'
      ),
      answer.summary
    );
    Assert.isTrue(
      answer.summary.contains('Closed is not ticked'),
      answer.summary
    );
    Assert.isTrue(
      answer.summary.contains('Close Date is earlier than today'),
      answer.summary
    );
    Assert.isTrue(answer.summary.contains('An open deal needs a future date.'));
    Assert.isTrue(answer.summary.length() <= 1200);
    Assert.isTrue(
      answer.fixSteps.contains('Set Close Date to today or a later date.'),
      String.join(answer.fixSteps, ' | ')
    );
    for (String step : answer.fixSteps) {
      Assert.isFalse(step.contains('Read the error message'), step);
    }
    Assert.isTrue(answer.fixSteps.size() <= 5);
    Assert.areEqual('Template', answer.source);
  }

  @IsTest
  static void anAllConditionRuleSaysAnyOneStoppingIsEnough() {
    ADA_Explanation answer = new ADA_TemplateProvider()
      .explain(ADA_LlmTestSupport.diagnosis(), richExtras());
    Assert.isTrue(
      answer.summary.contains('all of these are true'),
      answer.summary
    );
    Assert.isTrue(
      answer.summary.contains('as soon as any one of them is no longer true'),
      answer.summary
    );
  }

  @IsTest
  static void aFormulaThatCannotBeReadStillUsesTheMessageAndFields() {
    ADA_PayloadBuilder.Extras extras = richExtras();
    extras.conditionFormulaMasked = 'CASE(Status, "TEXT_1", true, false)';
    extras.fieldLabels = new List<String>{ 'Status', 'Reason' };
    ADA_Explanation answer = new ADA_TemplateProvider()
      .explain(ADA_LlmTestSupport.diagnosis(), extras);
    Assert.isTrue(answer.summary.contains('Close date cannot be in the past'));
    Assert.isFalse(answer.summary.contains('TEXT_1'), answer.summary);
    Assert.isTrue(
      String.join(answer.fixSteps, ' | ').contains('Status, Reason'),
      String.join(answer.fixSteps, ' | ')
    );
    Assert.isTrue(answer.fixSteps.size() <= 5);
  }

  @IsTest
  static void flowAndCodeMessagesAreQuoted() {
    for (
      ADA_ErrorType type : new List<ADA_ErrorType>{
        ADA_ErrorType.FLOW,
        ADA_ErrorType.APEX
      }
    ) {
      ADA_Explanation answer = new ADA_TemplateProvider()
        .explain(new ADA_Diagnosis(type, 0.9), richExtras());
      Assert.isTrue(
        answer.summary.contains('Close date cannot be in the past'),
        String.valueOf(type)
      );
    }
  }

  @IsTest
  static void aHugeMessageStillFitsTheLimits() {
    ADA_PayloadBuilder.Extras extras = richExtras();
    extras.ruleMessage = 'word '.repeat(2000);
    ADA_Diagnosis diagnosis = ADA_LlmTestSupport.diagnosis();
    diagnosis.description = 'detail '.repeat(500);
    ADA_Explanation answer = new ADA_TemplateProvider()
      .explain(diagnosis, extras);
    Assert.isTrue(
      answer.summary.length() <= 1200,
      '' + answer.summary.length()
    );
  }

  @IsTest
  static void unknownNeverPretendsToKnow() {
    ADA_Explanation answer = new ADA_TemplateProvider()
      .explain(ADA_Diagnosis.unknown(), null);
    Assert.isTrue(answer.summary.contains('not sure'));
  }
}

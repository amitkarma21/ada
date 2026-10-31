@IsTest
private class ADA_ExplanationServiceTest {
  private static final Datetime MODIFIED = Datetime.newInstanceGmt(
    2026,
    3,
    1,
    10,
    0,
    0
  );

  private static Boolean started = false;

  private static ADA_ExplanationService.Outcome run(
    ADA_PayloadBuilder.Extras extras
  ) {
    if (!started) {
      Test.startTest();
      started = true;
    }
    return ADA_ExplanationService.explain(
      ADA_LlmTestSupport.diagnosis(),
      extras
    );
  }

  private static void assertFellBack(
    ADA_ExplanationService.Outcome outcome,
    String reason
  ) {
    Assert.areEqual('Template', outcome.explanation.source);
    Assert.isNotNull(outcome.fallbackReason);
    Assert.isTrue(
      outcome.fallbackReason.containsIgnoreCase(reason),
      outcome.fallbackReason
    );
    Assert.isFalse(outcome.cached);
  }

  @IsTest
  static void templateSettingMakesNoCallout() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useProvider('Template', null);
    ADA_ExplanationService.Outcome outcome = run(ADA_LlmTestSupport.extras());
    Assert.areEqual(0, mock.calls);
    Assert.areEqual('Template', outcome.explanation.source);
    Assert.isNull(outcome.fallbackReason);
    Assert.isNull(outcome.payloadSent);
  }

  @IsTest
  static void aValidModelAnswerIsUsedAndTheExactPayloadIsReturned() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    ADA_ExplanationService.Outcome outcome = run(ADA_LlmTestSupport.extras());
    Assert.areEqual(1, mock.calls);
    Assert.areEqual('LLM', outcome.explanation.source);
    Assert.isNull(outcome.fallbackReason);
    Assert.areEqual(mock.requests[0].getBody(), outcome.payloadSent);
  }

  @IsTest
  static void aNullExtrasObjectIsAccepted() {
    ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    Assert.areEqual('LLM', run(null).explanation.source);
  }

  @IsTest
  static void invalidJsonFallsBackToTemplate() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.body = ADA_LlmTestSupport.envelope('I think it is the date.');
    ADA_LlmTestSupport.useOpenAi();
    ADA_ExplanationService.Outcome outcome = run(ADA_LlmTestSupport.extras());
    assertFellBack(outcome, 'rejected');
    Assert.isNotNull(outcome.payloadSent);
  }

  @IsTest
  static void extraFieldsFallBackToTemplate() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.body = ADA_LlmTestSupport.envelope(
      '{"explanation":"x","fixSteps":[],"suggestedAction":"NONE","run":"delete"}'
    );
    ADA_LlmTestSupport.useOpenAi();
    assertFellBack(run(ADA_LlmTestSupport.extras()), 'rejected');
  }

  @IsTest
  static void anActionOutsideTheAllowlistFallsBackToTemplate() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.body = ADA_LlmTestSupport.envelope(
      '{"explanation":"x","fixSteps":[],"suggestedAction":"DELETE_ALL"}'
    );
    ADA_LlmTestSupport.useOpenAi();
    assertFellBack(run(ADA_LlmTestSupport.extras()), 'rejected');
  }

  @IsTest
  static void rateLimitingFallsBackToTemplate() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.status = 429;
    ADA_LlmTestSupport.useOpenAi();
    assertFellBack(run(ADA_LlmTestSupport.extras()), '429');
  }

  @IsTest
  static void aTimeoutFallsBackToTemplate() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.timeout = true;
    ADA_LlmTestSupport.useOpenAi();
    assertFellBack(run(ADA_LlmTestSupport.extras()), 'timed out');
  }

  @IsTest
  static void theSecondExplanationForTheSameComponentMakesNoCallout() {
    insert ADA_LlmTestSupport.indexRow(MODIFIED);
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    ADA_PayloadBuilder.Extras extras = ADA_LlmTestSupport.extras();
    ADA_ExplanationService.Outcome first = run(extras);
    ADA_ExplanationService.Outcome second = run(extras);
    Assert.areEqual(1, mock.calls);
    Assert.isFalse(first.cached);
    Assert.isTrue(second.cached);
    Assert.areEqual(first.explanation.summary, second.explanation.summary);
    Assert.isNull(second.payloadSent);
  }

  @IsTest
  static void aTypedQuestionBypassesTheCache() {
    insert ADA_LlmTestSupport.indexRow(MODIFIED);
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_LlmTestSupport.useOpenAi();
    ADA_PayloadBuilder.Extras asked = ADA_LlmTestSupport.extras();
    asked.userQuestion = 'Why can I not save this deal?';
    run(asked);
    ADA_ExplanationService.Outcome again = run(asked);
    Assert.areEqual(2, mock.calls);
    Assert.isFalse(again.cached);
    Assert.isNull(
      [SELECT Explanation_Json__c FROM ADA_Metadata_Index__c LIMIT 1]
      .Explanation_Json__c
    );
  }

  @IsTest
  static void aFailedCallDoesNotPoisonTheCache() {
    insert ADA_LlmTestSupport.indexRow(MODIFIED);
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.status = 500;
    ADA_LlmTestSupport.useOpenAi();
    run(ADA_LlmTestSupport.extras());
    mock.status = 200;
    ADA_ExplanationService.Outcome retry = run(ADA_LlmTestSupport.extras());
    Assert.areEqual(2, mock.calls);
    Assert.areEqual('LLM', retry.explanation.source);
  }
}

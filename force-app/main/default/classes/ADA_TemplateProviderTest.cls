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

  @IsTest
  static void unknownNeverPretendsToKnow() {
    ADA_Explanation answer = new ADA_TemplateProvider()
      .explain(ADA_Diagnosis.unknown(), null);
    Assert.isTrue(answer.summary.contains('not sure'));
  }
}

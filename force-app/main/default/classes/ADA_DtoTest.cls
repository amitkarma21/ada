@IsTest
private class ADA_DtoTest {
  @IsTest
  static void diagnosisDefaultsAndClamping() {
    ADA_Diagnosis d = new ADA_Diagnosis(ADA_ErrorType.VALIDATION_RULE, 1.5);
    Assert.areEqual(1, d.confidence);
    Assert.areEqual(ADA_SuggestedAction.EXPLAIN_ONLY, d.suggestedAction);
    Assert.isTrue(d.fieldApiNames.isEmpty());
    Assert.areEqual(0, new ADA_Diagnosis(ADA_ErrorType.FLOW, -2).confidence);
    Assert.areEqual(0, new ADA_Diagnosis(ADA_ErrorType.FLOW, null).confidence);
  }

  @IsTest
  static void diagnosisCarriesComponentDetails() {
    ADA_Diagnosis d = new ADA_Diagnosis(ADA_ErrorType.VALIDATION_RULE, 0.9);
    d.objectApiName = 'Opportunity';
    d.componentType = 'ValidationRule';
    d.componentApiName = 'Close_Date_Rule';
    d.componentLabel = 'Close date in the future';
    d.description = 'Blocks past close dates';
    d.fieldApiNames = new List<String>{ 'CloseDate' };
    d.suggestedAction = ADA_SuggestedAction.REQUEST_ACCESS;
    Assert.areEqual('Opportunity', d.objectApiName);
    Assert.areEqual('ValidationRule', d.componentType);
    Assert.areEqual('Close_Date_Rule', d.componentApiName);
    Assert.areEqual('Close date in the future', d.componentLabel);
    Assert.areEqual('Blocks past close dates', d.description);
    Assert.areEqual(1, d.fieldApiNames.size());
    Assert.areEqual(ADA_SuggestedAction.REQUEST_ACCESS, d.suggestedAction);
  }

  @IsTest
  static void diagnosisNullTypeBecomesUnknown() {
    Assert.areEqual(
      ADA_ErrorType.UNKNOWN,
      new ADA_Diagnosis(null, 0.9).errorType
    );
  }

  @IsTest
  static void diagnosisConfidenceThreshold() {
    Assert.isTrue(
      new ADA_Diagnosis(ADA_ErrorType.ACCESS, 0.8).isConfident(0.8)
    );
    Assert.isFalse(
      new ADA_Diagnosis(ADA_ErrorType.ACCESS, 0.79).isConfident(0.8)
    );
    Assert.isFalse(
      new ADA_Diagnosis(ADA_ErrorType.UNKNOWN, 1).isConfident(0.8)
    );
    Assert.areEqual(ADA_ErrorType.UNKNOWN, ADA_Diagnosis.unknown().errorType);
  }

  @IsTest
  static void explanationDefaults() {
    ADA_Explanation e = new ADA_Explanation(null, null, null);
    Assert.areEqual('', e.summary);
    Assert.isTrue(e.fixSteps.isEmpty());
    Assert.areEqual('Template', e.source);
    ADA_Explanation full = new ADA_Explanation(
      'Why',
      new List<String>{ 'One' },
      'LLM'
    );
    Assert.areEqual('Why', full.summary);
    Assert.areEqual(1, full.fixSteps.size());
    Assert.areEqual('LLM', full.source);
  }

  @IsTest
  static void actionResultFactories() {
    ADA_ActionResult ok = ADA_ActionResult.ok('AzureDevOps', 'Created');
    Assert.isTrue(ok.success);
    Assert.areEqual('Success', ok.status);
    ADA_ActionResult failed = ADA_ActionResult.failed('Email', 'Nope');
    Assert.isFalse(failed.success);
    Assert.areEqual('Failed', failed.status);
    ADA_ActionResult blocked = ADA_ActionResult.blocked('LLM', 'PII');
    Assert.isFalse(blocked.success);
    Assert.areEqual('Blocked', blocked.status);
    Assert.areEqual('LLM', blocked.target);
    ok.externalId = '123';
    ok.externalUrl = 'external-link-123';
    Assert.areEqual('123', ok.externalId);
    Assert.areEqual('external-link-123', ok.externalUrl);
    Assert.areEqual('Created', ok.message);
  }
}

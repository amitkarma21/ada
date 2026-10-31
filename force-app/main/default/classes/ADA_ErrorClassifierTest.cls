@IsTest
private class ADA_ErrorClassifierTest {
  private static ADA_Diagnosis diagnosis(
    ADA_ErrorType type,
    Decimal confidence
  ) {
    return new ADA_Diagnosis(type, confidence);
  }

  private static ADA_ErrorClassifier classifier(
    List<ADA_Diagnosis> results,
    Decimal threshold
  ) {
    List<ADA_IMatcher> matchers = new List<ADA_IMatcher>();
    for (ADA_Diagnosis result : results) {
      matchers.add(new ADA_MatcherTestSupport.FixedMatcher(result));
    }
    return new ADA_ErrorClassifier(matchers, threshold);
  }

  private static ADA_ErrorContext context(String message) {
    return ADA_MatcherTestSupport.context(
      new ADA_MatcherTestSupport.FakeStore(),
      'Case',
      message
    );
  }

  @IsTest
  static void theFirstConfidentMatcherWins() {
    ADA_Diagnosis result = classifier(
        new List<ADA_Diagnosis>{
          null,
          diagnosis(ADA_ErrorType.VALIDATION_RULE, 0.9)
        },
        0.8
      )
      .classify(context('anything'));
    Assert.areEqual(ADA_ErrorType.VALIDATION_RULE, result.errorType);
    Assert.areEqual(0.9, result.confidence);
  }

  @IsTest
  static void twoConfidentMatchersMakeTheAnswerUncertain() {
    ADA_Diagnosis result = classifier(
        new List<ADA_Diagnosis>{
          diagnosis(ADA_ErrorType.VALIDATION_RULE, 1),
          diagnosis(ADA_ErrorType.FLOW, 0.95)
        },
        0.8
      )
      .classify(context('anything'));
    Assert.isFalse(result.isConfident(0.8));
    Assert.areEqual(0.79, result.confidence);
  }

  @IsTest
  static void aWeakSecondOpinionDoesNotLowerTheWinner() {
    ADA_Diagnosis result = classifier(
        new List<ADA_Diagnosis>{
          diagnosis(ADA_ErrorType.VALIDATION_RULE, 1),
          diagnosis(ADA_ErrorType.FLOW, 0.6)
        },
        0.8
      )
      .classify(context('anything'));
    Assert.areEqual(1, result.confidence);
  }

  @IsTest
  static void withoutAConfidentMatcherTheClosestCandidateIsReturnedUnconfident() {
    ADA_Diagnosis result = classifier(
        new List<ADA_Diagnosis>{
          diagnosis(ADA_ErrorType.FLOW, 0.62),
          diagnosis(ADA_ErrorType.APEX, 0.7)
        },
        0.8
      )
      .classify(context('anything'));
    Assert.areEqual(ADA_ErrorType.APEX, result.errorType);
    Assert.isFalse(result.isConfident(0.8));
  }

  @IsTest
  static void noSignalAtAllIsUnknown() {
    ADA_Diagnosis result = classifier(
        new List<ADA_Diagnosis>{ null, null },
        0.8
      )
      .classify(context('anything'));
    Assert.areEqual(ADA_ErrorType.UNKNOWN, result.errorType);
    Assert.areEqual(0, result.confidence);
  }

  @IsTest
  static void aBlankMessageIsUnknownWithoutAskingAnyMatcher() {
    ADA_Diagnosis result = classifier(
        new List<ADA_Diagnosis>{ diagnosis(ADA_ErrorType.FLOW, 1) },
        0.8
      )
      .classify(context('   '));
    Assert.areEqual(ADA_ErrorType.UNKNOWN, result.errorType);
  }

  @IsTest
  static void aBlankObjectIsUnknownEvenWhenAMatcherHasAnOpinion() {
    ADA_Diagnosis result = classifier(
        new List<ADA_Diagnosis>{ diagnosis(ADA_ErrorType.FLOW, 1) },
        0.8
      )
      .classify(
        ADA_MatcherTestSupport.context(
          new ADA_MatcherTestSupport.FakeStore(),
          null,
          'anything'
        )
      );
    Assert.areEqual(ADA_ErrorType.UNKNOWN, result.errorType);
  }

  @IsTest
  static void theThresholdIsClamped() {
    Assert.areEqual(
      0.8,
      new ADA_ErrorClassifier(new List<ADA_IMatcher>(), null).threshold
    );
    Assert.areEqual(
      ADA_ErrorClassifier.THRESHOLD_FLOOR,
      new ADA_ErrorClassifier(new List<ADA_IMatcher>(), 0.1).threshold
    );
    Assert.areEqual(
      1,
      new ADA_ErrorClassifier(new List<ADA_IMatcher>(), 7).threshold
    );
    Assert.areEqual(
      0.9,
      new ADA_ErrorClassifier(new List<ADA_IMatcher>(), 0.9).threshold
    );
  }

  @IsTest
  static void theDefaultMatchersRunInTheDocumentedOrder() {
    List<ADA_IMatcher> matchers = ADA_ErrorClassifier.defaultMatchers();
    Assert.areEqual(6, matchers.size());
    Assert.isTrue(matchers[0] instanceof ADA_RequiredFieldMatcher);
    Assert.isTrue(matchers[1] instanceof ADA_ValidationRuleMatcher);
    Assert.isTrue(matchers[2] instanceof ADA_DuplicateRuleMatcher);
    Assert.isTrue(matchers[3] instanceof ADA_AccessChecker);
    Assert.isTrue(matchers[4] instanceof ADA_FlowErrorMatcher);
    Assert.isTrue(matchers[5] instanceof ADA_ApexErrorMatcher);
  }

  @IsTest
  static void aDiagnosisConfidenceCanOnlyBeLowered() {
    ADA_Diagnosis result = diagnosis(ADA_ErrorType.FLOW, 0.5);
    result.capConfidence(0.9);
    Assert.areEqual(0.5, result.confidence);
    result.capConfidence(0.2);
    Assert.areEqual(0.2, result.confidence);
  }
}

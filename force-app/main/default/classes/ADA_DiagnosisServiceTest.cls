@IsTest
private class ADA_DiagnosisServiceTest {
  private static ADA_MatcherTestSupport.FakeStore store() {
    return new ADA_MatcherTestSupport.FakeStore()
      .add(
        ADA_MatcherTestSupport.messageRow(
          'ValidationRule',
          'Opportunity',
          'Close_Date_Rule',
          'Close date cannot be in the past for an open opportunity.'
        )
      )
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
          'ValidationRule',
          'Case',
          'Close_Reason_Rule',
          'Please choose a reason before closing the case.'
        )
      )
      .add(
        ADA_MatcherTestSupport.messageRow(
          'Flow',
          'Case',
          'Escalation_Flow',
          'Escalated cases must have High priority.'
        )
      )
      .add(
        ADA_MatcherTestSupport.messageRow(
          'ApexTrigger',
          'Case',
          'Case_Trigger',
          'Cases that arrive from the web must have an Origin.'
        )
      )
      .add(
        ADA_MatcherTestSupport.plainRow(
          'DuplicateRule',
          'Account',
          'Standard_Rule',
          null
        )
      )
      .add(
        ADA_MatcherTestSupport.plainRow(
          'DuplicateRule',
          'Account',
          'Custom_Rule',
          null
        )
      )
      .add(
        ADA_MatcherTestSupport.plainRow(
          'RequiredField',
          'Opportunity',
          'Opportunity',
          'CloseDate,Name,StageName'
        )
      );
  }

  private static void expect(
    String objectName,
    String message,
    ADA_ErrorType type,
    String component
  ) {
    ADA_Diagnosis result = ADA_DiagnosisService.diagnose(
      objectName,
      message,
      store()
    );
    Assert.areEqual(type, result.errorType, message);
    Assert.isTrue(result.isConfident(0.8), message + ' ' + result.confidence);
    if (component != null) {
      Assert.areEqual(component, result.componentApiName, message);
    }
  }

  @IsTest
  static void everyKnownErrorKindIsDiagnosedFromTheIndex() {
    expect(
      'Opportunity',
      'Close date cannot be in the past for an open opportunity.',
      ADA_ErrorType.VALIDATION_RULE,
      'Close_Date_Rule'
    );
    expect(
      'Opportunity',
      'Opportunities over 100,000 need a description.',
      ADA_ErrorType.VALIDATION_RULE,
      'Large_Deal_Rule'
    );
    expect(
      'Case',
      'Please choose a reason before closing the case.',
      ADA_ErrorType.VALIDATION_RULE,
      'Close_Reason_Rule'
    );
    expect(
      'Case',
      'Escalated cases must have High priority.',
      ADA_ErrorType.FLOW,
      'Escalation_Flow'
    );
    expect(
      'Case',
      'Cases that arrive from the web must have an Origin.',
      ADA_ErrorType.APEX,
      'Case_Trigger'
    );
    expect(
      'Account',
      'Use one of these records?',
      ADA_ErrorType.DUPLICATE_RULE,
      null
    );
    expect(
      'Opportunity',
      'Required fields are missing: [StageName, CloseDate]',
      ADA_ErrorType.REQUIRED_FIELD,
      null
    );
    expect(
      'Opportunity',
      'Operation failed due to fields being inaccessible on Sobject Opportunity, check errors on Exception or Result!  fieldNames: Amount',
      ADA_ErrorType.ACCESS,
      'Amount'
    );
  }

  @IsTest
  static void messagesNoOneHasSeenAreNeverConfident() {
    for (
      String message : new List<String>{
        'Something unexpected went wrong while processing your request.',
        'The quarterly forecast must be approved before Friday.',
        'Please contact your administrator.',
        'Close date cannot be in the past for a closed opportunity.',
        'Escalated cases must have Low priority.'
      }
    ) {
      for (
        String objectName : new List<String>{ 'Opportunity', 'Case', 'Account' }
      ) {
        ADA_Diagnosis result = ADA_DiagnosisService.diagnose(
          objectName,
          message,
          store()
        );
        Assert.isFalse(
          result.isConfident(0.8),
          objectName +
            ': ' +
            message +
            ' => ' +
            result.errorType +
            ' ' +
            result.confidence
        );
      }
    }
  }

  @IsTest
  static void theMessageOfAnotherObjectIsNotAnswered() {
    ADA_Diagnosis result = ADA_DiagnosisService.diagnose(
      'Opportunity',
      'Escalated cases must have High priority.',
      store()
    );
    Assert.isFalse(result.isConfident(0.8));
  }

  @IsTest
  static void aSameMessageInAFlowAndARuleIsAmbiguous() {
    ADA_MatcherTestSupport.FakeStore both = store()
      .add(
        ADA_MatcherTestSupport.messageRow(
          'Flow',
          'Opportunity',
          'Close_Date_Flow',
          'Close date cannot be in the past for an open opportunity.'
        )
      );
    ADA_Diagnosis result = ADA_DiagnosisService.diagnose(
      'Opportunity',
      'Close date cannot be in the past for an open opportunity.',
      both
    );
    Assert.isFalse(result.isConfident(0.8));
  }

  @IsTest
  static void aBlankObjectOrMessageIsUnknown() {
    Assert.areEqual(
      ADA_ErrorType.UNKNOWN,
      ADA_DiagnosisService.diagnose(
          null,
          'Required fields are missing: [Name]',
          store()
        )
        .errorType
    );
    Assert.areEqual(
      ADA_ErrorType.UNKNOWN,
      ADA_DiagnosisService.diagnose('Case', null, store()).errorType
    );
  }

  @IsTest
  static void theIndexIsReadOnceForOneDiagnosis() {
    ADA_MatcherTestSupport.FakeStore fake = store();
    ADA_DiagnosisService.diagnose(
      'Case',
      'Escalated cases must have High priority.',
      fake
    );
    Assert.areEqual(1, fake.loads);
  }

  @IsTest
  static void theThresholdComesFromTheDefaultSetting() {
    Assert.areEqual(0.8, ADA_DiagnosisService.threshold());
    ADA_DiagnosisService.thresholdOverride = 0.95;
    Assert.areEqual(0.95, ADA_DiagnosisService.threshold());
    ADA_DiagnosisService.thresholdOverride = 0.1;
    Assert.areEqual(
      ADA_ErrorClassifier.THRESHOLD_FLOOR,
      ADA_DiagnosisService.threshold()
    );
  }

  @IsTest
  static void aHigherThresholdTurnsAWeakMatchIntoNotSure() {
    ADA_MatcherTestSupport.FakeStore fake = new ADA_MatcherTestSupport.FakeStore()
      .add(
        ADA_MatcherTestSupport.messageRow(
          'Flow',
          'Case',
          'Escalation_Flow',
          'Cannot escalate {!Case.Subject} without a priority.'
        )
      );
    String message = 'Cannot escalate Printer jam without a priority.';
    ADA_Diagnosis relaxed = ADA_DiagnosisService.diagnose(
      'Case',
      message,
      fake
    );
    Assert.areEqual(ADA_ErrorType.FLOW, relaxed.errorType);
    Assert.isTrue(relaxed.isConfident(ADA_DiagnosisService.threshold()));
    ADA_DiagnosisService.thresholdOverride = 0.9;
    Assert.isFalse(
      ADA_DiagnosisService.diagnose('Case', message, fake)
        .isConfident(ADA_DiagnosisService.threshold())
    );
  }

  @IsTest
  static void theHarnessReturnsTheKeysTheGoldenRunnerReads() {
    Map<String, Object> result = ADA_DiagnosisService.diagnoseForHarness(
      'Case',
      'Please contact your administrator.'
    );
    Assert.isTrue(result.containsKey('type'));
    Assert.isTrue(result.containsKey('componentApiName'));
    Assert.isTrue(result.containsKey('confidence'));
    Assert.isTrue(result.containsKey('cpuMs'));
    Assert.areEqual(0.8, (Decimal) result.get('threshold'));
    Assert.areNotEqual('VALIDATION_RULE', result.get('type'));
  }
}

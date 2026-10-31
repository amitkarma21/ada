@IsTest
private class ADA_TemplateMatcherTest {
  private static final String CLOSE_DATE = 'Close date cannot be in the past for an open opportunity.';

  private static ADA_Metadata_Index__c rule(String apiName, String message) {
    ADA_Metadata_Index__c row = ADA_MatcherTestSupport.messageRow(
      'ValidationRule',
      'Opportunity',
      apiName,
      message
    );
    row.Field_Api_Names__c = 'IsClosed,CloseDate';
    row.Description__c = 'An open deal needs a future date.';
    return row;
  }

  private static ADA_Diagnosis validate(
    ADA_MatcherTestSupport.FakeStore store,
    String message
  ) {
    return new ADA_ValidationRuleMatcher()
      .match(ADA_MatcherTestSupport.context(store, 'Opportunity', message));
  }

  @IsTest
  static void validationRuleExactMessageIsAConfidentMatch() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(rule('Close_Date_Rule', CLOSE_DATE))
      .add(
        rule('Other_Rule', 'Opportunities over 100,000 need a description.')
      );
    ADA_Diagnosis result = validate(store, CLOSE_DATE);
    Assert.areEqual(ADA_ErrorType.VALIDATION_RULE, result.errorType);
    Assert.areEqual('Close_Date_Rule', result.componentApiName);
    Assert.areEqual('ValidationRule', result.componentType);
    Assert.areEqual('Opportunity', result.objectApiName);
    Assert.areEqual(1, result.confidence);
    Assert.areEqual(
      new List<String>{ 'IsClosed', 'CloseDate' },
      result.fieldApiNames
    );
    Assert.areEqual('An open deal needs a future date.', result.description);
  }

  @IsTest
  static void thePlatformWrapperAroundTheMessageIsIgnored() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(rule('Close_Date_Rule', CLOSE_DATE));
    ADA_Diagnosis result = validate(
      store,
      'Update failed. First exception on row 0 with id 006000000000001; first error: ' +
        'FIELD_CUSTOM_VALIDATION_EXCEPTION, ' +
        CLOSE_DATE +
        ': [CloseDate]'
    );
    Assert.areEqual('Close_Date_Rule', result.componentApiName);
    Assert.areEqual(1, result.confidence);
  }

  @IsTest
  static void anUnrelatedMessageHasNoMatch() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(rule('Close_Date_Rule', CLOSE_DATE));
    Assert.isNull(
      validate(
        store,
        'Something unexpected went wrong while processing your request.'
      )
    );
    Assert.isNull(validate(store, ''));
    Assert.isNull(validate(store, null));
  }

  @IsTest
  static void aNearMissIsNotAConfidentMatch() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(rule('Close_Date_Rule', CLOSE_DATE));
    ADA_Diagnosis result = validate(
      store,
      'Close date cannot be in the past for a closed opportunity.'
    );
    Assert.isTrue(
      result == null || !result.isConfident(0.8),
      'A one-word difference must not be a confident answer'
    );
  }

  @IsTest
  static void anInactiveRuleCannotBeTheCause() {
    ADA_Metadata_Index__c inactive = rule('Close_Date_Rule', CLOSE_DATE);
    inactive.Active__c = false;
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(inactive);
    Assert.isNull(validate(store, CLOSE_DATE));
  }

  @IsTest
  static void rulesOnOtherObjectsAreNotCandidates() {
    ADA_Metadata_Index__c other = rule('Close_Date_Rule', CLOSE_DATE);
    other.Object_Api_Name__c = 'Case';
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(other);
    Assert.isNull(validate(store, CLOSE_DATE));
  }

  @IsTest
  static void twoRulesWithTheSameMessageTieBelowTheThreshold() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(rule('Rule_One', CLOSE_DATE))
      .add(rule('Rule_Two', CLOSE_DATE));
    ADA_Diagnosis result = validate(store, CLOSE_DATE);
    Assert.isNotNull(result);
    Assert.isFalse(result.isConfident(0.8));
    Assert.areEqual(ADA_TemplateMatcher.TIE_CONFIDENCE, result.confidence);
  }

  @IsTest
  static void anExactMatchBeatsAFarWeakerSibling() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(rule('Exact_Rule', CLOSE_DATE))
      .add(
        rule(
          'Weak_Rule',
          'Close date cannot be in the past for an open opportunity owner.'
        )
      );
    ADA_Diagnosis result = validate(store, CLOSE_DATE);
    Assert.areEqual('Exact_Rule', result.componentApiName);
    Assert.isTrue(result.isConfident(0.8));
  }

  @IsTest
  static void aMessageWithAMergedValueStillMatchesTheTemplate() {
    ADA_Metadata_Index__c flow = ADA_MatcherTestSupport.messageRow(
      'Flow',
      'Case',
      'Escalation_Flow',
      'Cannot escalate {!Case.Subject} without a priority.'
    );
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(flow);
    ADA_Diagnosis result = new ADA_FlowErrorMatcher()
      .match(
        ADA_MatcherTestSupport.context(
          store,
          'Case',
          'Cannot escalate Printer jam without a priority.'
        )
      );
    Assert.areEqual(ADA_ErrorType.FLOW, result.errorType);
    Assert.areEqual('Escalation_Flow', result.componentApiName);
    Assert.isTrue(result.isConfident(0.8), 'Actual ' + result.confidence);
  }

  @IsTest
  static void eachMatcherReadsOnlyItsOwnComponentType() {
    ADA_Metadata_Index__c flow = ADA_MatcherTestSupport.messageRow(
      'Flow',
      'Opportunity',
      'Some_Flow',
      CLOSE_DATE
    );
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(flow);
    Assert.isNull(validate(store, CLOSE_DATE));
    Assert.isNull(
      new ADA_ApexErrorMatcher()
        .match(ADA_MatcherTestSupport.context(store, 'Opportunity', CLOSE_DATE))
    );
    Assert.areEqual(
      'Some_Flow',
      new ADA_FlowErrorMatcher()
        .match(ADA_MatcherTestSupport.context(store, 'Opportunity', CLOSE_DATE))
        .componentApiName
    );
  }

  @IsTest
  static void apexMatcherFindsAnyOfSeveralTriggerMessages() {
    ADA_Metadata_Index__c apexTrigger = ADA_MatcherTestSupport.messageRow(
      'ApexTrigger',
      'Case',
      'Case_Trigger',
      'Cases that arrive from the web must have an Origin.\nClosed cases cannot be reopened by this user.'
    );
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(apexTrigger);
    ADA_Diagnosis result = new ADA_ApexErrorMatcher()
      .match(
        ADA_MatcherTestSupport.context(
          store,
          'Case',
          'Closed cases cannot be reopened by this user.'
        )
      );
    Assert.areEqual(ADA_ErrorType.APEX, result.errorType);
    Assert.areEqual('Case_Trigger', result.componentApiName);
    Assert.areEqual('ApexTrigger', result.componentType);
  }

  @IsTest
  static void theIndexIsReadOncePerContext() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(rule('Close_Date_Rule', CLOSE_DATE));
    ADA_ErrorContext context = ADA_MatcherTestSupport.context(
      store,
      'Opportunity',
      CLOSE_DATE
    );
    new ADA_ValidationRuleMatcher().match(context);
    new ADA_FlowErrorMatcher().match(context);
    new ADA_ApexErrorMatcher().match(context);
    Assert.areEqual(1, store.loads);
  }

  @IsTest
  static void aBlankObjectNeverReadsTheIndex() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(rule('Close_Date_Rule', CLOSE_DATE));
    ADA_ErrorContext context = ADA_MatcherTestSupport.context(
      store,
      null,
      CLOSE_DATE
    );
    Assert.isNull(new ADA_ValidationRuleMatcher().match(context));
    Assert.areEqual(0, store.loads);
  }
}

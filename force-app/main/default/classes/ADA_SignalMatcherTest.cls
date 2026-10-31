@IsTest
private class ADA_SignalMatcherTest {
  private static final String REQUIRED_MESSAGE = 'Required fields are missing: [StageName, CloseDate]';
  private static final String ACCESS_MESSAGE =
    'Operation failed due to fields being inaccessible on Sobject Opportunity, ' +
    'check errors on Exception or Result!  fieldNames: Amount';

  private static ADA_MatcherTestSupport.FakeStore requiredStore() {
    return new ADA_MatcherTestSupport.FakeStore()
      .add(
        ADA_MatcherTestSupport.plainRow(
          'RequiredField',
          'Opportunity',
          'Opportunity',
          'CloseDate,Name,StageName'
        )
      );
  }

  private static ADA_Diagnosis required(
    ADA_MatcherTestSupport.FakeStore store,
    String message
  ) {
    return new ADA_RequiredFieldMatcher()
      .match(ADA_MatcherTestSupport.context(store, 'Opportunity', message));
  }

  @IsTest
  static void requiredFieldsAreParsedFromThePlatformMessage() {
    ADA_Diagnosis result = required(requiredStore(), REQUIRED_MESSAGE);
    Assert.areEqual(ADA_ErrorType.REQUIRED_FIELD, result.errorType);
    Assert.areEqual(
      new List<String>{ 'StageName', 'CloseDate' },
      result.fieldApiNames
    );
    Assert.areEqual(ADA_RequiredFieldMatcher.CONFIRMED, result.confidence);
    Assert.areEqual('RequiredField', result.componentType);
    Assert.isNull(result.componentApiName);
  }

  @IsTest
  static void fieldsMissingFromTheIndexAreStillReportedWithLessConfidence() {
    ADA_Diagnosis result = required(
      requiredStore(),
      'Required fields are missing: [Custom_Thing__c]'
    );
    Assert.areEqual(
      new List<String>{ 'Custom_Thing__c' },
      result.fieldApiNames
    );
    Assert.areEqual(ADA_RequiredFieldMatcher.SIGNALLED, result.confidence);
    Assert.isTrue(result.isConfident(0.8));
  }

  @IsTest
  static void aStatusCodeWithoutAFieldListIsStillRecognised() {
    ADA_Diagnosis result = required(
      requiredStore(),
      'REQUIRED_FIELD_MISSING: Please fill in the form'
    );
    Assert.areEqual(ADA_ErrorType.REQUIRED_FIELD, result.errorType);
    Assert.isTrue(result.fieldApiNames.isEmpty());
    Assert.areEqual(ADA_RequiredFieldMatcher.SIGNALLED, result.confidence);
  }

  @IsTest
  static void theInterfaceWordingIsRecognised() {
    Assert.isNotNull(required(requiredStore(), 'Complete this field.'));
    Assert.isNotNull(required(requiredStore(), 'You must enter a value'));
  }

  @IsTest
  static void textThatOnlyMentionsRequiredFieldsIsNotAMatch() {
    Assert.isNull(
      required(requiredStore(), 'Required fields help reporting stay accurate.')
    );
    Assert.isNull(
      required(requiredStore(), 'Please contact your administrator.')
    );
    Assert.isNull(required(requiredStore(), null));
  }

  @IsTest
  static void aBracketThatIsNotAFieldNameIsDropped() {
    ADA_Diagnosis result = required(
      requiredStore(),
      'Required fields are missing: [StageName, <script>alert(1)</script>]'
    );
    Assert.areEqual(new List<String>{ 'StageName' }, result.fieldApiNames);
  }

  private static ADA_Diagnosis duplicate(
    ADA_MatcherTestSupport.FakeStore store,
    String message
  ) {
    return new ADA_DuplicateRuleMatcher()
      .match(ADA_MatcherTestSupport.context(store, 'Account', message));
  }

  private static ADA_Metadata_Index__c duplicateRule(String apiName) {
    return ADA_MatcherTestSupport.plainRow(
      'DuplicateRule',
      'Account',
      apiName,
      null
    );
  }

  @IsTest
  static void aSingleActiveDuplicateRuleIsNamed() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(duplicateRule('Account_Duplicates'));
    ADA_Diagnosis result = duplicate(store, 'Use one of these records?');
    Assert.areEqual(ADA_ErrorType.DUPLICATE_RULE, result.errorType);
    Assert.areEqual('Account_Duplicates', result.componentApiName);
    Assert.areEqual(ADA_DuplicateRuleMatcher.WORDED, result.confidence);
  }

  @IsTest
  static void severalActiveRulesLeaveTheComponentUnnamedButTheTypeConfident() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(duplicateRule('Rule_A'))
      .add(duplicateRule('Rule_B'));
    ADA_Diagnosis result = duplicate(store, 'Use one of these records?');
    Assert.isNull(result.componentApiName);
    Assert.isTrue(result.isConfident(0.8));
  }

  @IsTest
  static void noActiveRuleOnTheObjectKeepsTheAnswerBelowTheThreshold() {
    ADA_Metadata_Index__c inactive = duplicateRule('Rule_A');
    inactive.Active__c = false;
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(inactive);
    ADA_Diagnosis result = duplicate(store, 'Use one of these records?');
    Assert.areEqual(
      ADA_DuplicateRuleMatcher.NO_RULE_INDEXED,
      result.confidence
    );
    Assert.isFalse(result.isConfident(0.8));
  }

  @IsTest
  static void theStatusCodeGivesTheStrongestSignal() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(duplicateRule('Rule_A'));
    ADA_Diagnosis result = duplicate(
      store,
      'DUPLICATES_DETECTED, You\'re creating a duplicate record. We recommend you use an existing record instead.'
    );
    Assert.areEqual(ADA_DuplicateRuleMatcher.CODED, result.confidence);
  }

  @IsTest
  static void duplicateSoundingTextAboutOtherThingsIsNotAMatch() {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore()
      .add(duplicateRule('Rule_A'));
    Assert.isNull(
      duplicate(store, 'Remove the duplicate line items from this quote.')
    );
    Assert.isNull(duplicate(store, ''));
  }

  private static ADA_Diagnosis access(String message) {
    return new ADA_AccessChecker()
      .match(
        ADA_MatcherTestSupport.context(
          new ADA_MatcherTestSupport.FakeStore(),
          'Opportunity',
          message
        )
      );
  }

  @IsTest
  static void aFieldAccessFailureNamesTheFieldAndAsksForAccess() {
    ADA_Diagnosis result = access(ACCESS_MESSAGE);
    Assert.areEqual(ADA_ErrorType.ACCESS, result.errorType);
    Assert.areEqual(new List<String>{ 'Amount' }, result.fieldApiNames);
    Assert.areEqual('Amount', result.componentApiName);
    Assert.areEqual('Field', result.componentType);
    Assert.areEqual('Amount', result.componentLabel);
    Assert.areEqual(ADA_SuggestedAction.REQUEST_ACCESS, result.suggestedAction);
    Assert.areEqual(ADA_AccessChecker.WITH_FIELDS, result.confidence);
  }

  @IsTest
  static void severalInaccessibleFieldsAreAllListed() {
    ADA_Diagnosis result = access(
      'Operation failed due to fields being inaccessible on Sobject Opportunity, ' +
      'check errors on Exception or Result!  fieldNames: Amount, Description'
    );
    Assert.areEqual(
      new List<String>{ 'Amount', 'Description' },
      result.fieldApiNames
    );
    Assert.isNull(result.componentApiName);
  }

  @IsTest
  static void anUnknownFieldNameIsKeptWithoutALabel() {
    ADA_Diagnosis result = access(
      'Operation failed due to fields being inaccessible on Sobject Opportunity, fieldNames: Missing_Thing__c'
    );
    Assert.areEqual('Missing_Thing__c', result.componentApiName);
    Assert.isNull(result.componentLabel);
  }

  @IsTest
  static void anObjectLevelFailureWithoutFieldsIsAnObjectAccessAnswer() {
    ADA_Diagnosis result = access(
      'INSUFFICIENT_ACCESS_OR_READONLY, insufficient access rights on object id'
    );
    Assert.areEqual('Object', result.componentType);
    Assert.areEqual(ADA_AccessChecker.WITHOUT_FIELDS, result.confidence);
    Assert.isTrue(result.fieldApiNames.isEmpty());
    Assert.isTrue(
      access(
          'You do not have the level of access necessary to perform the operation you requested.'
        )
        .isConfident(0.8)
    );
  }

  @IsTest
  static void accessWordingThatIsNotAFailureIsNotAMatch() {
    Assert.isNull(
      access('Access to the quarterly report must be approved before Friday.')
    );
    Assert.isNull(access('Please contact your administrator.'));
    Assert.isNull(access(null));
  }

  @IsTest
  static void aBadObjectNameDoesNotBreakTheLabelLookup() {
    ADA_Diagnosis result = new ADA_AccessChecker()
      .match(
        ADA_MatcherTestSupport.context(
          new ADA_MatcherTestSupport.FakeStore(),
          'Not_An_Object__c',
          ACCESS_MESSAGE
        )
      );
    Assert.areEqual('Amount', result.componentApiName);
    Assert.isNull(result.componentLabel);
  }
}

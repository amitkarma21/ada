@IsTest
private class ADA_FlowErrorMatcherTest {
  private static final String UNHANDLED =
    'An unhandled fault has occurred in this flow\n' +
    'An unhandled fault has occurred while processing the flow. Please contact your system administrator for more information.';

  private static ADA_Metadata_Index__c flowRow(
    String apiName,
    String label,
    String message
  ) {
    ADA_Metadata_Index__c row = ADA_MatcherTestSupport.messageRow(
      'Flow',
      'Case',
      apiName,
      message
    );
    row.Label__c = label;
    return row;
  }

  private static ADA_Diagnosis run(
    ADA_MatcherTestSupport.FakeStore store,
    String message
  ) {
    return new ADA_FlowErrorMatcher()
      .match(ADA_MatcherTestSupport.context(store, 'Case', message));
  }

  private static ADA_MatcherTestSupport.FakeStore storeWith(
    List<ADA_Metadata_Index__c> rows
  ) {
    ADA_MatcherTestSupport.FakeStore store = new ADA_MatcherTestSupport.FakeStore();
    for (ADA_Metadata_Index__c row : rows) {
      store.add(row);
    }
    return store;
  }

  @IsTest
  static void anUnhandledFaultIsAFlowEvenWhenNoFlowIsNamed() {
    ADA_Diagnosis result = run(
      storeWith(new List<ADA_Metadata_Index__c>()),
      UNHANDLED
    );
    Assert.areEqual(ADA_ErrorType.FLOW, result.errorType);
    Assert.areEqual(ADA_FlowErrorMatcher.FAULT_CONFIDENCE, result.confidence);
    Assert.areEqual('Case', result.objectApiName);
    Assert.areEqual('Flow', result.componentType);
    Assert.isNull(result.componentApiName);
  }

  @IsTest
  static void theOtherFaultWordingsAreRecognised() {
    List<String> messages = new List<String>{
      'FLOW_ELEMENT_ERROR, The flow failed to access the value for myVar because it hasn\'t been set or assigned.',
      'This error occurred when the flow tried to create records: REQUIRED_FIELD_MISSING.',
      'The flow tried to update these records: 001000000000001. This error occurred: ENTITY_IS_LOCKED.',
      'Error element Get_Contacts (FlowRecordLookup). No records found.',
      'Error Occurred During Flow "Case Router": Something broke.',
      'Flow Interview Details: started by a user.',
      'Flow API Name: Case_Router'
    };
    for (String message : messages) {
      ADA_Diagnosis result = run(
        storeWith(new List<ADA_Metadata_Index__c>()),
        message
      );
      Assert.isNotNull(result, message);
      Assert.areEqual(ADA_ErrorType.FLOW, result.errorType, message);
    }
  }

  @IsTest
  static void aMessageThatOnlyMentionsFlowIsNotAFault() {
    List<String> messages = new List<String>{
      'Cash flow must be positive.',
      'Please review the flow of funds before saving.',
      'The workflow owner must be an active user.',
      'Escalated cases must have a manager.'
    };
    for (String message : messages) {
      Assert.isNull(
        run(storeWith(new List<ADA_Metadata_Index__c>()), message),
        message
      );
    }
  }

  @IsTest
  static void aCustomErrorFromTheIndexStillMatchesItsOwnRow() {
    ADA_MatcherTestSupport.FakeStore store = storeWith(
      new List<ADA_Metadata_Index__c>{
        flowRow(
          'Escalation',
          'Escalation',
          'Escalated cases must have High priority.'
        )
      }
    );
    ADA_Diagnosis result = run(
      store,
      'Escalated cases must have High priority.'
    );
    Assert.areEqual(ADA_ErrorType.FLOW, result.errorType);
    Assert.areEqual('Escalation', result.componentApiName);
    Assert.isTrue(result.confidence > ADA_FlowErrorMatcher.FAULT_CONFIDENCE);
  }

  @IsTest
  static void aFaultNamesTheFlowByApiName() {
    ADA_MatcherTestSupport.FakeStore store = storeWith(
      new List<ADA_Metadata_Index__c>{
        flowRow('Case_Router', 'Route new cases', null),
        flowRow('Case_Closer', 'Close cases', null)
      }
    );
    ADA_Diagnosis result = run(
      store,
      UNHANDLED + '\nFlow API Name: case_router'
    );
    Assert.areEqual('Case_Router', result.componentApiName);
    Assert.areEqual('Route new cases', result.componentLabel);
  }

  @IsTest
  static void aFaultNamesTheFlowByLabel() {
    ADA_MatcherTestSupport.FakeStore store = storeWith(
      new List<ADA_Metadata_Index__c>{
        flowRow('Case_Router', 'Route new cases', null)
      }
    );
    ADA_Diagnosis result = run(
      store,
      'Error Occurred During Flow "Route new cases": An unhandled fault has occurred.'
    );
    Assert.areEqual('Case_Router', result.componentApiName);
  }

  @IsTest
  static void theLongerNameWinsWhenOneNameContainsAnother() {
    ADA_MatcherTestSupport.FakeStore store = storeWith(
      new List<ADA_Metadata_Index__c>{
        flowRow('Case_Router', 'Case Router', null),
        flowRow('Case_Router_Escalated', 'Case Router Escalated', null)
      }
    );
    ADA_Diagnosis result = run(
      store,
      UNHANDLED + '\nFlow API Name: Case_Router_Escalated'
    );
    Assert.areEqual('Case_Router_Escalated', result.componentApiName);
  }

  @IsTest
  static void noComponentIsNamedWhenTwoFlowsFitEqually() {
    ADA_MatcherTestSupport.FakeStore store = storeWith(
      new List<ADA_Metadata_Index__c>{
        flowRow('Router_One', 'Case Router', null),
        flowRow('Router_Two', 'Case Router', null)
      }
    );
    ADA_Diagnosis result = run(
      store,
      'Error Occurred During Flow "Case Router": An unhandled fault has occurred.'
    );
    Assert.areEqual(ADA_ErrorType.FLOW, result.errorType);
    Assert.isNull(result.componentApiName);
  }

  @IsTest
  static void aFlowNameInsideAnotherWordIsNotNamed() {
    ADA_MatcherTestSupport.FakeStore store = storeWith(
      new List<ADA_Metadata_Index__c>{
        flowRow('Case_Router', 'Route new cases', null)
      }
    );
    ADA_Diagnosis result = run(
      store,
      UNHANDLED + '\nFlow API Name: Case_Router_Escalated'
    );
    Assert.isNull(result.componentApiName);
  }

  @IsTest
  static void anInactiveFlowIsNotNamed() {
    ADA_Metadata_Index__c row = flowRow('Case_Router', 'Case Router', null);
    row.Active__c = false;
    ADA_Diagnosis result = run(
      storeWith(new List<ADA_Metadata_Index__c>{ row }),
      UNHANDLED + '\nFlow API Name: Case_Router'
    );
    Assert.isNull(result.componentApiName);
  }

  @IsTest
  static void aOneWordLabelIsTooLooseToName() {
    ADA_MatcherTestSupport.FakeStore store = storeWith(
      new List<ADA_Metadata_Index__c>{ flowRow('Update', 'Update', null) }
    );
    ADA_Diagnosis result = run(
      store,
      'Error element Update_Case (FlowRecordUpdate). An unhandled fault has occurred.'
    );
    Assert.isNull(result.componentApiName);
  }

  @IsTest
  static void theFailingStepIsNamedInPlainWords() {
    ADA_Diagnosis result = run(
      storeWith(new List<ADA_Metadata_Index__c>()),
      'Error element Update_Case_Owner (FlowRecordUpdate). This error occurred: ENTITY_IS_LOCKED.'
    );
    Assert.isTrue(result.description.contains('Update_Case_Owner'));
    Assert.isTrue(result.description.contains('updating records'));
  }

  @IsTest
  static void anUnknownStepTypeStillNamesTheStep() {
    ADA_Diagnosis result = run(
      storeWith(new List<ADA_Metadata_Index__c>()),
      'Error element Do_Thing (FlowSomethingNew). Broke.'
    );
    Assert.isTrue(result.description.contains('Do_Thing'));
  }

  @IsTest
  static void textAfterTheStepIsNeverCopiedIntoTheDescription() {
    ADA_Diagnosis result = run(
      storeWith(new List<ADA_Metadata_Index__c>()),
      'Error element Update_Case (FlowRecordUpdate). This error occurred: FIELD_CUSTOM_VALIDATION_EXCEPTION: secret-value-123 for jo@example.com'
    );
    Assert.isFalse(result.description.contains('secret-value-123'));
    Assert.isFalse(result.description.contains('example.com'));
  }

  @IsTest
  static void aFlowDescriptionIsKeptAlongsideTheStep() {
    ADA_Metadata_Index__c row = flowRow('Case_Router', 'Case Router', null);
    row.Description__c = 'Routes new cases to a queue.';
    ADA_Diagnosis result = run(
      storeWith(new List<ADA_Metadata_Index__c>{ row }),
      'Error element Assign_Queue (FlowRecordUpdate). Flow API Name: Case_Router'
    );
    Assert.isTrue(result.description.contains('Routes new cases to a queue.'));
    Assert.isTrue(result.description.contains('Assign_Queue'));
  }

  @IsTest
  static void theClassifierTreatsAFaultAsAConfidentFlowAnswer() {
    ADA_ErrorClassifier classifier = new ADA_ErrorClassifier(
      ADA_ErrorClassifier.defaultMatchers(),
      0.8
    );
    ADA_Diagnosis result = classifier.classify(
      ADA_MatcherTestSupport.context(
        storeWith(new List<ADA_Metadata_Index__c>()),
        'Case',
        UNHANDLED
      )
    );
    Assert.areEqual(ADA_ErrorType.FLOW, result.errorType);
    Assert.isTrue(result.isConfident(0.8));
  }

  @IsTest
  static void aBlankMessageGivesNoAnswer() {
    Assert.isNull(run(storeWith(new List<ADA_Metadata_Index__c>()), '  '));
  }
}

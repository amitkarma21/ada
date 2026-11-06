@IsTest
private class ADA_FlowOutlineTest {
  private static Map<String, Object> filter(
    String field,
    String operator,
    Map<String, Object> value
  ) {
    return new Map<String, Object>{
      'field' => field,
      'operator' => operator,
      'value' => value
    };
  }

  private static Map<String, Object> text(String value) {
    return new Map<String, Object>{ 'stringValue' => value };
  }

  private static Map<String, Object> flag(Boolean value) {
    return new Map<String, Object>{ 'booleanValue' => value };
  }

  private static Map<String, Object> flowWith(
    String triggerType,
    String recordTrigger,
    String logic,
    List<Object> filters
  ) {
    Map<String, Object> start = new Map<String, Object>{
      'object' => 'Case',
      'triggerType' => triggerType,
      'recordTriggerType' => recordTrigger,
      'filterLogic' => logic,
      'filters' => filters
    };
    return new Map<String, Object>{ 'start' => start };
  }

  private static Map<String, Object> startOf(Map<String, Object> flow) {
    return (Map<String, Object>) flow.get('start');
  }

  @IsTest
  static void aBeforeSaveFlowWithTwoFiltersReadsAsOneAndedCondition() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'CreateAndUpdate',
        'and',
        new List<Object>{
          filter('IsEscalated', 'EqualTo', flag(true)),
          filter('Priority', 'NotEqualTo', text('High'))
        }
      )
    );
    Assert.areEqual(
      'before a record is saved (when it is created or updated)',
      outline.runsWhen
    );
    Assert.areEqual(
      'IsEscalated = TRUE && Priority <> \'TEXT_1\'',
      outline.conditionMasked
    );
  }

  @IsTest
  static void theMaskedConditionCanBeReadInPlainWords() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'Update',
        'and',
        new List<Object>{
          filter('IsEscalated', 'EqualTo', flag(true)),
          filter('Priority', 'NotEqualTo', text('High'))
        }
      )
    );
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      outline.conditionMasked,
      new Map<String, String>{
        'IsEscalated' => 'Escalated',
        'Priority' => 'Priority'
      }
    );
    Assert.isNotNull(reading);
    Assert.areEqual(ADA_FormulaReader.MODE_ALL, reading.mode);
    Assert.areEqual('Escalated is ticked', reading.conditions[0]);
    Assert.isTrue(reading.conditions[1].startsWith('Priority is not one of'));
  }

  @IsTest
  static void orLogicJoinsWithOr() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordAfterSave',
        'Create',
        'or',
        new List<Object>{
          filter('Status', 'EqualTo', text('New')),
          filter('Status', 'EqualTo', text('Working'))
        }
      )
    );
    Assert.areEqual(
      'Status = \'TEXT_1\' || Status = \'TEXT_2\'',
      outline.conditionMasked
    );
    Assert.areEqual(
      'after a record is saved (when it is created)',
      outline.runsWhen
    );
  }

  @IsTest
  static void customLogicKeepsItsGrouping() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'CreateAndUpdate',
        '1 AND (2 OR 3)',
        new List<Object>{
          filter('IsEscalated', 'EqualTo', flag(true)),
          filter('Priority', 'EqualTo', text('Low')),
          filter(
            'Amount__c',
            'GreaterThan',
            new Map<String, Object>{ 'numberValue' => 100 }
          )
        }
      )
    );
    Assert.areEqual(
      'IsEscalated = TRUE && (Priority = \'TEXT_1\' || Amount__c > 100)',
      outline.conditionMasked
    );
  }

  @IsTest
  static void customLogicThatDoesNotFitTheFiltersIsDropped() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'Update',
        '1 AND 7',
        new List<Object>{ filter('IsEscalated', 'EqualTo', flag(true)) }
      )
    );
    Assert.isNull(outline.conditionMasked);
    Assert.isNotNull(outline.runsWhen);
  }

  @IsTest
  static void customLogicWithOtherWordsIsDropped() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'Update',
        '1 AND Evil',
        new List<Object>{ filter('IsEscalated', 'EqualTo', flag(true)) }
      )
    );
    Assert.isNull(outline.conditionMasked);
  }

  @IsTest
  static void aFormulaConditionHasItsMergeFieldsUnwrappedAndItsTextMasked() {
    Map<String, Object> flow = flowWith(
      'RecordBeforeSave',
      'Update',
      'formula_evaluates_to_true',
      new List<Object>()
    );
    startOf(flow)
      .put(
        'filterFormula',
        'AND({!$Record.IsEscalated} = true, {!$Record.Priority} <> "High")'
      );
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(flow);
    Assert.areEqual(
      'AND(IsEscalated = true, Priority <> "TEXT_1")',
      outline.conditionMasked
    );
  }

  @IsTest
  static void aFlowWithNoFiltersHasNoCondition() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith('RecordAfterSave', 'Update', null, new List<Object>())
    );
    Assert.isNull(outline.conditionMasked);
    Assert.areEqual(
      'after a record is saved (when it is updated)',
      outline.runsWhen
    );
  }

  @IsTest
  static void aDeleteFlowHasNoEventSuffix() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith('RecordBeforeDelete', 'Delete', null, new List<Object>())
    );
    Assert.areEqual('before a record is deleted', outline.runsWhen);
  }

  @IsTest
  static void aFlowThatOnlyRunsWhenTheRecordChangesSaysSo() {
    Map<String, Object> flow = flowWith(
      'RecordAfterSave',
      'Update',
      'and',
      new List<Object>{ filter('Priority', 'EqualTo', text('High')) }
    );
    startOf(flow).put('doesRequireRecordChangedToMeetCriteria', true);
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(flow);
    Assert.isTrue(
      outline.runsWhen.endsWith(
        ', and only when the change makes the record meet its entry conditions'
      )
    );
  }

  @IsTest
  static void aTriggerTypeThatIsNotARecordSaveGivesNoTrigger() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith('Scheduled', null, null, new List<Object>())
    );
    Assert.isNull(outline.runsWhen);
  }

  @IsTest
  static void emptyOrUnexpectedMetadataGivesAnEmptyOutline() {
    Assert.isNull(ADA_FlowOutline.read(null).runsWhen);
    Assert.isNull(ADA_FlowOutline.read(new Map<String, Object>()).runsWhen);
    Assert.isNull(
      ADA_FlowOutline.read(new Map<String, Object>{ 'start' => 'not a map' })
        .conditionMasked
    );
  }

  @IsTest
  static void isNullFiltersBecomeBlankChecks() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'Update',
        'and',
        new List<Object>{
          filter('Reason__c', 'IsNull', flag(true)),
          filter('Owner__c', 'IsNull', flag(false))
        }
      )
    );
    Assert.areEqual(
      'ISBLANK(Reason__c) && NOT(ISBLANK(Owner__c))',
      outline.conditionMasked
    );
  }

  @IsTest
  static void anOperatorOrValueItCannotReadBecomesAnUnreadableCondition() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'Update',
        'and',
        new List<Object>{
          filter('Subject', 'Contains', text('refund')),
          filter(
            'Priority',
            'EqualTo',
            new Map<String, Object>{ 'elementReference' => 'varPriority' }
          )
        }
      )
    );
    Assert.areEqual(
      'FLOW_CONDITION(Subject) && FLOW_CONDITION(Priority)',
      outline.conditionMasked
    );
    Assert.isFalse(outline.conditionMasked.contains('refund'));
    Assert.isFalse(outline.conditionMasked.contains('varPriority'));
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      outline.conditionMasked,
      null
    );
    Assert.isNull(reading);
  }

  @IsTest
  static void aFieldNameThatIsNotAnApiNameIsNeverCopied() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'Update',
        'and',
        new List<Object>{ filter('Priority); DELETE', 'EqualTo', text('x')) }
      )
    );
    Assert.isFalse(outline.conditionMasked.contains('DELETE'));
    Assert.areEqual('FLOW_CONDITION(UNKNOWN)', outline.conditionMasked);
  }

  @IsTest
  static void textValuesAndIdsAreMaskedAndQuotesCannotBreakOut() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'Update',
        'and',
        new List<Object>{
          filter('Name', 'EqualTo', text('O\'Brien \\ Pty')),
          filter('OwnerId', 'EqualTo', text('005000000000001AAA'))
        }
      )
    );
    Assert.areEqual(
      'Name = \'TEXT_1\' && OwnerId = \'ID_1\'',
      outline.conditionMasked
    );
    Assert.isFalse(outline.conditionMasked.contains('Brien'));
  }

  @IsTest
  static void aDateValueIsMaskedLikeText() {
    ADA_FlowOutline.Outline outline = ADA_FlowOutline.read(
      flowWith(
        'RecordBeforeSave',
        'Update',
        'and',
        new List<Object>{
          filter(
            'CloseDate',
            'LessThan',
            new Map<String, Object>{ 'dateValue' => '2026-01-31' }
          )
        }
      )
    );
    Assert.areEqual('CloseDate < \'TEXT_1\'', outline.conditionMasked);
  }
}

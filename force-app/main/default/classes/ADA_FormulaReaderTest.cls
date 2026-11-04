@IsTest
private class ADA_FormulaReaderTest {
  private static final Map<String, String> LABELS = new Map<String, String>{
    'CloseDate' => 'Close Date',
    'IsClosed' => 'Closed',
    'Amount' => 'Amount',
    'Description' => 'Description',
    'Status' => 'Status',
    'Reason' => 'Reason'
  };

  @IsTest
  static void anOpenDealWithAPastCloseDateReadsInPlainEnglish() {
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      'AND(NOT(IsClosed), CloseDate < TODAY())',
      LABELS
    );
    Assert.areEqual(ADA_FormulaReader.MODE_ALL, reading.mode);
    Assert.areEqual(
      new List<String>{
        'Closed is not ticked',
        'Close Date is earlier than today'
      },
      reading.conditions
    );
    Assert.areEqual(
      new List<String>{ 'Set Close Date to today or a later date.' },
      reading.fixes
    );
  }

  @IsTest
  static void numbersAndBlankChecksGiveFieldSpecificFixes() {
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      'AND(Amount > 100000, ISBLANK(Description))',
      LABELS
    );
    Assert.areEqual(
      new List<String>{
        'Amount is greater than 100000',
        'Description is empty'
      },
      reading.conditions
    );
    Assert.areEqual(
      new List<String>{
        'Make Amount 100000 or less.',
        'Enter a value in Description.'
      },
      reading.fixes
    );
  }

  @IsTest
  static void maskedPicklistValuesAreNeverInvented() {
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      'AND(ISPICKVAL(Status, "TEXT_1"), ISBLANK(TEXT(Reason)))',
      LABELS
    );
    Assert.areEqual(
      new List<String>{
        'Status is set to one of the values the rule watches',
        'Reason is empty'
      },
      reading.conditions
    );
    Assert.areEqual(
      new List<String>{ 'Enter a value in Reason.' },
      reading.fixes
    );
    for (String text : reading.conditions) {
      Assert.isFalse(text.contains('TEXT_1'), text);
    }
  }

  @IsTest
  static void orAndASingleConditionKeepTheirMeaning() {
    ADA_FormulaReader.Reading either = ADA_FormulaReader.read(
      'OR(ISBLANK(Description), ISBLANK(Reason))',
      LABELS
    );
    Assert.areEqual(ADA_FormulaReader.MODE_ANY, either.mode);
    Assert.areEqual(2, either.fixes.size());
    ADA_FormulaReader.Reading one = ADA_FormulaReader.read(
      'ISBLANK(Description)',
      LABELS
    );
    Assert.areEqual(ADA_FormulaReader.MODE_ONE, one.mode);
    Assert.areEqual(new List<String>{ 'Description is empty' }, one.conditions);
  }

  @IsTest
  static void symbolOperatorsMatchTheFunctionForms() {
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      '!IsClosed && CloseDate < TODAY()',
      LABELS
    );
    Assert.areEqual(ADA_FormulaReader.MODE_ALL, reading.mode);
    Assert.areEqual(
      new List<String>{
        'Closed is not ticked',
        'Close Date is earlier than today'
      },
      reading.conditions
    );
    Assert.areEqual(
      ADA_FormulaReader.MODE_ANY,
      ADA_FormulaReader.read('ISBLANK(Description) || ISBLANK(Reason)', LABELS)
        .mode
    );
  }

  @IsTest
  static void negationFlipsComparisonsAndAppliesDeMorgan() {
    ADA_FormulaReader.Reading flipped = ADA_FormulaReader.read(
      'NOT(CloseDate >= TODAY())',
      LABELS
    );
    Assert.areEqual(
      new List<String>{ 'Close Date is earlier than today' },
      flipped.conditions
    );
    ADA_FormulaReader.Reading both = ADA_FormulaReader.read(
      'NOT(AND(ISBLANK(Description), ISBLANK(Reason)))',
      LABELS
    );
    Assert.areEqual(ADA_FormulaReader.MODE_ANY, both.mode);
    Assert.areEqual(
      new List<String>{ 'Description is filled in', 'Reason is filled in' },
      both.conditions
    );
  }

  @IsTest
  static void aLiteralOnTheLeftIsTurnedAround() {
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      'TODAY() > CloseDate',
      LABELS
    );
    Assert.areEqual(
      new List<String>{ 'Close Date is earlier than today' },
      reading.conditions
    );
  }

  @IsTest
  static void booleanFieldsCompareToTrueAndFalse() {
    Assert.areEqual(
      new List<String>{ 'Closed is ticked' },
      ADA_FormulaReader.read('IsClosed = TRUE', LABELS).conditions
    );
    Assert.areEqual(
      new List<String>{ 'Closed is not ticked' },
      ADA_FormulaReader.read('IsClosed = FALSE', LABELS).conditions
    );
  }

  @IsTest
  static void fieldsWithoutALabelAreMadeReadable() {
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      'ISBLANK(Close_Reason__c)',
      null
    );
    Assert.areEqual(
      new List<String>{ 'Close Reason is empty' },
      reading.conditions
    );
  }

  @IsTest
  static void aPartlyUnderstoodFormulaSaysSoWithoutGuessing() {
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      'AND(CASE(Status, "TEXT_1", true, false), ISBLANK(Reason))',
      LABELS
    );
    Assert.areEqual(
      new List<String>{
        'another condition set by your admin',
        'Reason is empty'
      },
      reading.conditions
    );
    Assert.areEqual(
      new List<String>{ 'Enter a value in Reason.' },
      reading.fixes
    );
  }

  @IsTest
  static void whatCannotBeReadReturnsNullAndNeverThrows() {
    Assert.isNull(ADA_FormulaReader.read(null, LABELS));
    Assert.isNull(ADA_FormulaReader.read('   ', LABELS));
    Assert.isNull(ADA_FormulaReader.read('AND(ISBLANK(Reason', LABELS));
    Assert.isNull(ADA_FormulaReader.read(')(', LABELS));
    Assert.isNull(
      ADA_FormulaReader.read('CASE(Status, "TEXT_1", true, false)', LABELS)
    );
    Assert.isNull(
      ADA_FormulaReader.read('AND('.repeat(200) + 'x' + ')'.repeat(200), LABELS)
    );
    Assert.isNull(ADA_FormulaReader.read('x'.repeat(5000), LABELS));
  }

  @IsTest
  static void everyComparisonHasAReadableForm() {
    Map<String, String> expected = new Map<String, String>{
      'Amount >= 5' => 'Amount is 5 or more',
      'Amount < 5' => 'Amount is less than 5',
      'Amount <= 5' => 'Amount is 5 or less',
      'Amount = 5' => 'Amount is 5',
      'Amount <> 5' => 'Amount is not 5',
      'CloseDate <= TODAY()' => 'Close Date is today or earlier',
      'CloseDate > TODAY()' => 'Close Date is later than today',
      'CloseDate >= TODAY()' => 'Close Date is today or later',
      'CloseDate = TODAY()' => 'Close Date is today',
      'CloseDate != TODAY()' => 'Close Date is not today',
      'Amount == -5' => 'Amount is -5',
      'Status = "TEXT_1"' => 'Status is set to one of the values the rule watches',
      'Status != "TEXT_1"' => 'Status is not one of the values the rule watches',
      'NOT(ISPICKVAL(Status, "TEXT_1"))' => 'Status is not one of the values the rule watches',
      'NOT(ISBLANK(Reason))' => 'Reason is filled in',
      'Amount > CloseDate' => 'Amount is greater than Close Date',
      'Amount >= CloseDate' => 'Amount is greater than or equal to Close Date',
      'Amount < CloseDate' => 'Amount is less than Close Date',
      'Amount <= CloseDate' => 'Amount is less than or equal to Close Date',
      'Amount = CloseDate' => 'Amount is the same as Close Date',
      'Amount != CloseDate' => 'Amount is different from Close Date'
    };
    for (String formula : expected.keySet()) {
      ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
        formula,
        LABELS
      );
      Assert.isNotNull(reading, formula);
      Assert.areEqual(
        new List<String>{ expected.get(formula) },
        reading.conditions,
        formula
      );
    }
  }

  @IsTest
  static void aGroupInsideAGroupIsShownInBrackets() {
    ADA_FormulaReader.Reading reading = ADA_FormulaReader.read(
      'AND(Amount > 5, OR(ISBLANK(Description), ISBLANK(Reason)))',
      LABELS
    );
    Assert.areEqual(ADA_FormulaReader.MODE_ALL, reading.mode);
    Assert.areEqual(
      new List<String>{
        'Amount is greater than 5',
        '(Description is empty or Reason is empty)'
      },
      reading.conditions
    );
    Assert.areEqual(
      new List<String>{ 'Make Amount 5 or less.' },
      reading.fixes
    );
  }

  @IsTest
  static void relatedFieldsAndArithmeticAreHandledSafely() {
    Assert.areEqual(
      new List<String>{ 'Industry is empty' },
      ADA_FormulaReader.read('ISBLANK(Account.Industry)', null).conditions
    );
    Assert.isNull(ADA_FormulaReader.read('Amount * 2 > 100 + 5', LABELS));
    Assert.isNull(ADA_FormulaReader.read('Amount # 5', LABELS));
    Assert.isNull(ADA_FormulaReader.read('Status = "open', LABELS));
    Assert.isNull(ADA_FormulaReader.read('AND()', LABELS));
    Assert.isNull(ADA_FormulaReader.read('NOT(a, b)', LABELS));
  }
}

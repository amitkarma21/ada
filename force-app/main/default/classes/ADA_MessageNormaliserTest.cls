@IsTest
private class ADA_MessageNormaliserTest {
  @IsTest
  static void lowerCasesAndStripsPunctuation() {
    Assert.areEqual(
      'close date cannot be in the past for an open opportunity',
      ADA_MessageNormaliser.normalise(
        'Close date cannot be in the past for an open opportunity.'
      )
    );
  }

  @IsTest
  static void stripsTheDmlWrapperAndStatusCodeAndFieldSuffix() {
    Assert.areEqual(
      'close date cannot be in the past for an open opportunity',
      ADA_MessageNormaliser.normalise(
        'Update failed. First exception on row 0 with id 006000000000001AAA; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, Close date cannot be in the past for an open opportunity.: [CloseDate]'
      )
    );
  }

  @IsTest
  static void stripsALeadingStatusCodeOnly() {
    Assert.areEqual(
      'please choose a reason before closing the case',
      ADA_MessageNormaliser.normalise(
        'FIELD_CUSTOM_VALIDATION_EXCEPTION: Please choose a reason before closing the case.'
      )
    );
  }

  @IsTest
  static void collapsesWhitespaceAndNewlines() {
    Assert.areEqual(
      'opportunities over 100 000 need a description',
      ADA_MessageNormaliser.normalise(
        '  Opportunities   over\n100,000\tneed a  description  '
      )
    );
  }

  @IsTest
  static void dropsApostrophesInsteadOfSplittingWords() {
    Assert.areEqual(
      'you cant save this',
      ADA_MessageNormaliser.normalise('You can\'t save this!')
    );
  }

  @IsTest
  static void keepsTheRequiredFieldsSentenceWithoutTheFieldList() {
    Assert.areEqual(
      'required fields are missing',
      ADA_MessageNormaliser.normalise(
        'Required fields are missing: [StageName, CloseDate]'
      )
    );
  }

  @IsTest
  static void dropsFlowMergeFields() {
    Assert.areEqual(
      'case is locked until review',
      ADA_MessageNormaliser.normalise(
        'Case {!$Record.CaseNumber} is locked until {!reviewDate} review'
      )
    );
  }

  @IsTest
  static void blankGivesEmptyString() {
    Assert.areEqual('', ADA_MessageNormaliser.normalise(null));
    Assert.areEqual('', ADA_MessageNormaliser.normalise('   '));
  }

  @IsTest
  static void normalisesEachLineOfAMultiMessageText() {
    Assert.areEqual(
      'first one\nsecond one',
      ADA_MessageNormaliser.normaliseLines('First one.\nSecond, one!')
    );
  }
}

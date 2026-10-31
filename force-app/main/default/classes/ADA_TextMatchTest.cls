@IsTest
private class ADA_TextMatchTest {
  private static final String RULE = 'close date cannot be in the past for an open opportunity';

  @IsTest
  static void identicalTextScoresOne() {
    Assert.areEqual(1, ADA_TextMatch.score(RULE, RULE));
  }

  @IsTest
  static void blankOrUnrelatedTextScoresZero() {
    Assert.areEqual(0, ADA_TextMatch.score('', RULE));
    Assert.areEqual(0, ADA_TextMatch.score(RULE, null));
    Assert.areEqual(
      0,
      ADA_TextMatch.score(
        'something unexpected went wrong while processing',
        RULE
      )
    );
  }

  @IsTest
  static void templatesUnderThreeWordsMatchOnlyExactly() {
    Assert.areEqual(1, ADA_TextMatch.score('not allowed', 'not allowed'));
    Assert.areEqual(
      0,
      ADA_TextMatch.score('this is not allowed here', 'not allowed')
    );
  }

  @IsTest
  static void aMergedValueInsideTheMessageStaysConfident() {
    Decimal score = ADA_TextMatch.score(
      'cannot escalate acme without a priority',
      'cannot escalate without a priority'
    );
    Assert.isTrue(score >= 0.8, 'Actual ' + score);
    Assert.isTrue(
      score < 1,
      'An approximate match must never equal an exact one'
    );
  }

  @IsTest
  static void aSingleChangedWordFallsBelowTheThreshold() {
    Decimal score = ADA_TextMatch.score(
      'close date cannot be in the past for a closed opportunity',
      RULE
    );
    Assert.isTrue(score < 0.6, 'Actual ' + score);
  }

  @IsTest
  static void aMissingWordFallsBelowTheThreshold() {
    Decimal score = ADA_TextMatch.score(
      'close date cannot be in the past for open opportunity',
      RULE
    );
    Assert.isTrue(score < 0.8, 'Actual ' + score);
  }

  @IsTest
  static void aLongMessageWithTheTemplateBuriedInItIsNotConfident() {
    Decimal score = ADA_TextMatch.score(
      'close date cannot be in the past for an open opportunity ' +
      'and also several other unrelated problems were found while saving the record today',
      RULE
    );
    Assert.isTrue(score < 0.8, 'Actual ' + score);
  }

  @IsTest
  static void oversizedTextIsRejected() {
    List<String> words = new List<String>();
    for (Integer i = 0; i < 130; i++) {
      words.add('word' + i);
    }
    String text = String.join(words, ' ');
    Assert.areEqual(0, ADA_TextMatch.score(text + ' extra', text));
  }

  @IsTest
  static void aRowScoresAsItsBestLine() {
    ADA_Metadata_Index__c row = new ADA_Metadata_Index__c(
      Message_Normalised__c = 'first message about nothing\n' + RULE
    );
    Assert.areEqual(1, ADA_TextMatch.scoreRow(RULE, row));
    Assert.areEqual(
      0,
      ADA_TextMatch.scoreRow(RULE, new ADA_Metadata_Index__c())
    );
  }
}

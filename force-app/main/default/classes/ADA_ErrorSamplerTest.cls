@IsTest
private class ADA_ErrorSamplerTest {
  @IsTest
  static void aBlankMessageGivesNoSample() {
    Assert.isNull(ADA_ErrorSampler.sample(null));
    Assert.isNull(ADA_ErrorSampler.sample('   '));
  }

  @IsTest
  static void theSampleIsLowerCasedAndLosesPunctuation() {
    Assert.areEqual(
      'the stage is not allowed here',
      ADA_ErrorSampler.sample('The Stage is NOT allowed, here!')
    );
  }

  @IsTest
  static void personalDataIsScrubbedBeforeItIsKept() {
    String sample = ADA_ErrorSampler.sample(
      'Cannot notify jane.citizen@mail.example.com.au about the change'
    );
    Assert.isFalse(sample.contains('jane'));
    Assert.isFalse(sample.contains('example'));
    Assert.isTrue(sample.contains('cannot notify'));
  }

  @IsTest
  static void numbersAreDroppedBecauseTheyCanBeAmountsOrIds() {
    String sample = ADA_ErrorSampler.sample(
      'Discount of 125000 is over the limit of 5000 for order 00012345'
    );
    Assert.isFalse(Pattern.compile('[0-9]').matcher(sample).find());
    Assert.isTrue(sample.contains('is over the limit'));
  }

  @IsTest
  static void theWrapperAroundTheMessageIsRemoved() {
    Assert.areEqual(
      'something odd happened',
      ADA_ErrorSampler.sample(
        'Update failed. First exception on row 0; first error: UNKNOWN_EXCEPTION, Something odd happened: []'
      )
    );
  }

  @IsTest
  static void aLongMessageIsClipped() {
    String sample = ADA_ErrorSampler.sample('word '.repeat(200));
    Assert.isTrue(sample.length() <= ADA_ErrorSampler.MAX_SAMPLE);
    Assert.isTrue(sample.length() >= ADA_ErrorSampler.MAX_SAMPLE - 1);
  }

  @IsTest
  static void aMessageThatIsOnlyNumbersGivesNoSample() {
    Assert.isNull(ADA_ErrorSampler.sample('12345 67890'));
  }
}

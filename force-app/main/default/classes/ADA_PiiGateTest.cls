@IsTest
private class ADA_PiiGateTest {
  @IsTest
  static void emailAddressesAreScrubbed() {
    ADA_PiiGate.Result result = ADA_PiiGate.scrub(
      'Ask jane.citizen+work@mail.example.com.au about it'
    );
    Assert.areEqual('Ask [EMAIL] about it', result.text);
    Assert.isTrue(result.kinds.contains('EMAIL'));
    Assert.isTrue(result.changed());
  }

  @IsTest
  static void australianPhoneNumbersInEveryCommonFormatAreScrubbed() {
    for (
      String number1 : new List<String>{
        '0412 345 678',
        '0412345678',
        '04 1234 5678',
        '+61 412 345 678',
        '+61412345678',
        '(02) 9876 5432',
        '02 9876 5432',
        '02-9876-5432',
        '+61 2 9876 5432'
      }
    ) {
      ADA_PiiGate.Result result = ADA_PiiGate.scrub(
        'Call me on ' + number1 + ' please'
      );
      Assert.areEqual('Call me on [PHONE] please', result.text, number1);
    }
  }

  @IsTest
  static void numbersThatMerelyLookLikePhonesAreLeftAlone() {
    for (
      String text : new List<String>{
        'Rule 4521 failed on line 0207',
        'Validation VR-2024-0045 blocked the save',
        'Opportunities over 100,000 need a description.',
        'Record 006000000000001AAA is locked',
        'API version 68.0 only',
        'Saved at 2026-10-31T06:21:45Z',
        'Confidence 0.98 for 1234567.89'
      }
    ) {
      ADA_PiiGate.Result result = ADA_PiiGate.scrub(text);
      Assert.areEqual(text, result.text, text);
      Assert.isFalse(result.changed());
    }
  }

  @IsTest
  static void taxFileNumbersMustPassTheChecksum() {
    Assert.areEqual(
      'My TFN is [TFN] ok',
      ADA_PiiGate.scrub('My TFN is 123 456 782 ok').text
    );
    Assert.areEqual(
      'My TFN is [TFN] ok',
      ADA_PiiGate.scrub('My TFN is 123456782 ok').text
    );
    Assert.areEqual(
      'Reference 123 456 789 ok',
      ADA_PiiGate.scrub('Reference 123 456 789 ok').text
    );
  }

  @IsTest
  static void cardNumbersMustPassTheLuhnCheck() {
    Assert.areEqual(
      'Paid with [CARD] today',
      ADA_PiiGate.scrub('Paid with 4111 1111 1111 1111 today').text
    );
    Assert.areEqual(
      'Paid with [CARD] today',
      ADA_PiiGate.scrub('Paid with 4111-1111-1111-1111 today').text
    );
    Assert.areEqual(
      'Order 4111 1111 1111 1112 shipped',
      ADA_PiiGate.scrub('Order 4111 1111 1111 1112 shipped').text
    );
  }

  @IsTest
  static void aPhoneNumberIsNotMistakenForATaxFileNumber() {
    ADA_PiiGate.Result result = ADA_PiiGate.scrub('Call +61 412 345 678');
    Assert.areEqual('Call [PHONE]', result.text);
    Assert.isFalse(result.kinds.contains('TFN'));
  }

  @IsTest
  static void accountAndContactNamesInTheTextAreScrubbed() {
    insert new Account(Name = 'Acme Pty Ltd');
    insert new Contact(FirstName = 'Jane', LastName = 'Citizen');
    ADA_PiiGate.Result result = ADA_PiiGate.scrub(
      'Jane Citizen cannot save Acme Pty Ltd today'
    );
    Assert.areEqual('[NAME] cannot save [NAME] today', result.text);
    Assert.isTrue(result.kinds.contains('NAME'));
  }

  @IsTest
  static void aNameThatIsNotARecordIsKept() {
    insert new Account(Name = 'Acme Pty Ltd');
    ADA_PiiGate.Result result = ADA_PiiGate.scrub(
      'Escalated Cases need High Priority for Globex'
    );
    Assert.areEqual(
      'Escalated Cases need High Priority for Globex',
      result.text
    );
    Assert.isFalse(result.changed());
  }

  @IsTest
  static void aSingleWordAccountNameIsScrubbed() {
    insert new Account(Name = 'Globex');
    Assert.areEqual(
      'Why is [NAME] locked?',
      ADA_PiiGate.scrub('Why is Globex locked?').text
    );
  }

  @IsTest
  static void theLongestMatchingNameWins() {
    insert new Account(Name = 'Acme');
    insert new Account(Name = 'Acme Pty Ltd');
    Assert.areEqual(
      '[NAME] is on hold',
      ADA_PiiGate.scrub('Acme Pty Ltd is on hold').text
    );
  }

  @IsTest
  static void aHugeNumberOfCapitalisedWordsStaysWithinLimits() {
    List<String> words = new List<String>();
    for (Integer i = 0; i < 300; i++) {
      words.add('Word' + i);
    }
    ADA_PiiGate.scrub(String.join(words, ' '));
    Assert.isTrue(Limits.getQueries() <= 2);
  }

  @IsTest
  static void detectNeverRunsAQueryAndFindsPatternsOnly() {
    insert new Account(Name = 'Globex');
    Integer before = Limits.getQueries();
    Set<String> kinds = ADA_PiiGate.detect(
      'Globex wrote to a@b.example.com from 0412 345 678'
    );
    Assert.areEqual(before, Limits.getQueries());
    Assert.areEqual(new Set<String>{ 'EMAIL', 'PHONE' }, kinds);
    Assert.isTrue(ADA_PiiGate.detect('nothing personal here').isEmpty());
  }

  @IsTest
  static void scrubPatternsDoesNotTouchNames() {
    insert new Account(Name = 'Globex');
    Assert.areEqual(
      'Globex and [EMAIL]',
      ADA_PiiGate.scrubPatterns('Globex and a@b.example.com').text
    );
  }

  @IsTest
  static void blankTextPassesThrough() {
    Assert.areEqual('', ADA_PiiGate.scrub('').text);
    Assert.isNull(ADA_PiiGate.scrub(null).text);
    Assert.isTrue(ADA_PiiGate.detect(null).isEmpty());
  }

  @IsTest
  static void theShippedPatternsAreActive() {
    Set<String> names = new Set<String>();
    for (ADA_Pii_Pattern__mdt pattern : ADA_PiiGate.activePatterns()) {
      names.add(pattern.DeveloperName);
    }
    Assert.isTrue(
      names.containsAll(
        new Set<String>{ 'Card_Number', 'Email', 'Phone_AU', 'Tax_File_Number' }
      )
    );
  }

  @IsTest
  static void anAdministratorPatternIsAppliedAndRedacted() {
    ADA_PiiGate.patternOverride = new List<ADA_Pii_Pattern__mdt>{
      new ADA_Pii_Pattern__mdt(
        DeveloperName = 'Staff_Code',
        Regex__c = 'STAFF-\\d{4}',
        Active__c = true
      ),
      new ADA_Pii_Pattern__mdt(
        DeveloperName = 'Retired_Code',
        Regex__c = 'OLD-\\d{4}',
        Active__c = false
      ),
      new ADA_Pii_Pattern__mdt(
        DeveloperName = 'Broken',
        Regex__c = '([unclosed',
        Active__c = true
      ),
      new ADA_Pii_Pattern__mdt(
        DeveloperName = 'Empty',
        Regex__c = '',
        Active__c = true
      )
    };
    ADA_PiiGate.Result result = ADA_PiiGate.scrub(
      'Badge STAFF-1234 and OLD-5678'
    );
    Assert.areEqual('Badge [REDACTED] and OLD-5678', result.text);
    Assert.isTrue(result.kinds.contains('REDACTED'));
  }
}

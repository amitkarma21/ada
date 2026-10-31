@IsTest
private class ADA_PayloadBuilderTest {
  private static final Set<String> ALLOWED = new Set<String>{
    'errorType',
    'objectApiName',
    'objectLabel',
    'componentType',
    'componentApiName',
    'componentLabel',
    'componentDescription',
    'conditionFormulaMasked',
    'fieldLabels',
    'missingPermissionLabels',
    'userQuestion',
    'locale'
  };

  private static ADA_Diagnosis diagnosis() {
    ADA_Diagnosis result = new ADA_Diagnosis(ADA_ErrorType.VALIDATION_RULE, 1);
    result.objectApiName = 'Opportunity';
    result.componentType = 'ValidationRule';
    result.componentApiName = 'Close_Date_Rule';
    result.componentLabel = 'Close Date Rule';
    result.description = 'An open deal needs a future date.';
    return result;
  }

  private static ADA_PayloadBuilder.Extras extras() {
    ADA_PayloadBuilder.Extras extras = new ADA_PayloadBuilder.Extras();
    extras.objectLabel = 'Opportunity';
    extras.conditionFormulaMasked = 'AND(NOT(IsClosed), CloseDate < TODAY())';
    extras.fieldLabels = new List<String>{ 'Close Date', 'Closed' };
    extras.missingPermissionLabels = new List<String>{ 'Sales Operations' };
    extras.userQuestion = 'Why can I not save this deal?';
    extras.locale = 'en_AU';
    return extras;
  }

  @IsTest
  static void theBodyCarriesExactlyTheDocumentedFields() {
    String json = ADA_PayloadBuilder.toJson(
      ADA_PayloadBuilder.forLlm(diagnosis(), extras())
    );
    Map<String, Object> parsed = (Map<String, Object>) System.JSON.deserializeUntyped(
      json
    );
    Assert.areEqual(ALLOWED, parsed.keySet());
    Assert.areEqual('VALIDATION_RULE', parsed.get('errorType'));
    Assert.areEqual('Close_Date_Rule', parsed.get('componentApiName'));
    Assert.areEqual('en_AU', parsed.get('locale'));
    Assert.areEqual(
      'AND(NOT(IsClosed), CloseDate < TODAY())',
      parsed.get('conditionFormulaMasked')
    );
  }

  @IsTest
  static void emptyFieldsAreOmitted() {
    String json = ADA_PayloadBuilder.toJson(
      ADA_PayloadBuilder.forLlm(
        new ADA_Diagnosis(ADA_ErrorType.UNKNOWN, 0),
        null
      )
    );
    Map<String, Object> parsed = (Map<String, Object>) System.JSON.deserializeUntyped(
      json
    );
    Assert.isTrue(ALLOWED.containsAll(parsed.keySet()));
    Assert.areEqual('UNKNOWN', parsed.get('errorType'));
    Assert.isFalse(parsed.containsKey('userQuestion'));
  }

  @IsTest
  static void freeTextIsScrubbedBeforeItIsPlacedInTheBody() {
    ADA_Diagnosis result = diagnosis();
    result.description = 'Ask jane@example.com.au or 0412 345 678.';
    result.componentLabel = 'Rule for 4111 1111 1111 1111';
    ADA_PayloadBuilder.Extras extras = extras();
    extras.userQuestion = 'My TFN 123 456 782 and email jane@example.com.au';
    String json = ADA_PayloadBuilder.toJson(
      ADA_PayloadBuilder.forLlm(result, extras)
    );
    Assert.isFalse(json.contains('jane@'));
    Assert.isFalse(json.contains('0412'));
    Assert.isFalse(json.contains('4111'));
    Assert.isFalse(json.contains('123 456 782'));
    Assert.isTrue(json.contains('[EMAIL]'));
    Assert.isTrue(json.contains('[PHONE]'));
    Assert.isTrue(json.contains('[CARD]'));
    Assert.isTrue(json.contains('[TFN]'));
  }

  @IsTest
  static void recordNamesInTheQuestionAreScrubbed() {
    insert new Account(Name = 'Globex');
    ADA_PayloadBuilder.Extras extras = extras();
    extras.userQuestion = 'Why can I not save Globex?';
    ADA_PayloadBuilder.LlmBody body = ADA_PayloadBuilder.forLlm(
      diagnosis(),
      extras
    );
    Assert.areEqual('Why can I not save [NAME]?', body.userQuestion);
  }

  @IsTest
  static void aFormulaThatStillHoldsLiteralsIsMaskedAgain() {
    ADA_PayloadBuilder.Extras extras = extras();
    extras.conditionFormulaMasked = 'Account.Name = \'Acme Pty Ltd\' && OwnerId = \'005000000000001AAA\'';
    ADA_PayloadBuilder.LlmBody body = ADA_PayloadBuilder.forLlm(
      diagnosis(),
      extras
    );
    Assert.areEqual(
      'Account.Name = \'TEXT_1\' && OwnerId = \'ID_1\'',
      body.conditionFormulaMasked
    );
  }

  @IsTest
  static void lengthsAndListsAreCapped() {
    ADA_PayloadBuilder.Extras extras = extras();
    extras.userQuestion = 'q'.repeat(2000);
    extras.conditionFormulaMasked = 'x'.repeat(5000);
    extras.fieldLabels = new List<String>();
    for (Integer i = 0; i < 60; i++) {
      extras.fieldLabels.add('Label ' + i);
    }
    ADA_Diagnosis result = diagnosis();
    result.description = 'd'.repeat(3000);
    ADA_PayloadBuilder.LlmBody body = ADA_PayloadBuilder.forLlm(result, extras);
    Assert.areEqual(
      ADA_PayloadBuilder.MAX_QUESTION,
      body.userQuestion.length()
    );
    Assert.areEqual(
      ADA_PayloadBuilder.MAX_FORMULA,
      body.conditionFormulaMasked.length()
    );
    Assert.areEqual(
      ADA_PayloadBuilder.MAX_DESCRIPTION,
      body.componentDescription.length()
    );
    Assert.areEqual(ADA_PayloadBuilder.MAX_LIST, body.fieldLabels.size());
  }

  @IsTest
  static void labelsInListsAreScrubbedToo() {
    ADA_PayloadBuilder.Extras extras = extras();
    extras.fieldLabels = new List<String>{
      'Contact jane@example.com.au',
      null,
      'Close Date'
    };
    ADA_PayloadBuilder.LlmBody body = ADA_PayloadBuilder.forLlm(
      diagnosis(),
      extras
    );
    Assert.areEqual(
      new List<String>{ 'Contact [EMAIL]', 'Close Date' },
      body.fieldLabels
    );
  }

  @IsTest
  static void theLocaleDefaultsToTheRunningUsersLocale() {
    ADA_PayloadBuilder.Extras extras = extras();
    extras.locale = null;
    Assert.areEqual(
      UserInfo.getLocale(),
      ADA_PayloadBuilder.forLlm(diagnosis(), extras).locale
    );
  }
}

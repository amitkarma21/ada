@IsTest
private class ADA_MessageLiteralsTest {
  @IsTest
  static void findsASimpleLiteral() {
    List<String> found = ADA_MessageLiterals.fromAddError(
      'c.addError(\'Cases that arrive from the web must have an Origin.\');'
    );
    Assert.areEqual(
      new List<String>{ 'Cases that arrive from the web must have an Origin.' },
      found
    );
  }

  @IsTest
  static void concatenationBecomesATemplate() {
    List<String> found = ADA_MessageLiterals.fromAddError(
      'rec.addError(\'Owner \' + u.Name + \' cannot close \' + n + \' cases\');'
    );
    Assert.areEqual(
      new List<String>{ 'Owner {} cannot close {} cases' },
      found
    );
  }

  @IsTest
  static void leadingAndTrailingVariablesAreMarked() {
    Assert.areEqual(
      new List<String>{ '{} is locked {}' },
      ADA_MessageLiterals.fromAddError(
        'a.addError(name + \' is locked \' + String.valueOf(n));'
      )
    );
  }

  @IsTest
  static void ignoresTheSecondArgumentAndCommasInsideQuotes() {
    Assert.areEqual(
      new List<String>{ 'Stop, right now' },
      ADA_MessageLiterals.fromAddError(
        'a.addError(\'Stop, right now\', false);'
      )
    );
  }

  @IsTest
  static void handlesEscapedQuotesAndFieldForm() {
    Assert.areEqual(
      new List<String>{ 'It\'s not allowed' },
      ADA_MessageLiterals.fromAddError(
        'a.Name.addError(\'It\\\'s not allowed\');'
      )
    );
  }

  @IsTest
  static void skipsCallsWithoutALiteralAndDuplicates() {
    List<String> found = ADA_MessageLiterals.fromAddError(
      'a.addError(msg); b.addError(Label.Oops); c.addError(\'Twice\'); d.addError(\'Twice\');'
    );
    Assert.areEqual(new List<String>{ 'Twice' }, found);
  }

  @IsTest
  static void blankOrUnterminatedInputIsSafe() {
    Assert.isTrue(ADA_MessageLiterals.fromAddError(null).isEmpty());
    Assert.isTrue(ADA_MessageLiterals.fromAddError('').isEmpty());
    Assert.isNotNull(ADA_MessageLiterals.fromAddError('a.addError(\'open'));
    Assert.isNotNull(ADA_MessageLiterals.fromAddError('a.addError('));
  }

  @IsTest
  static void listsCalledClassNamesWithoutBuiltIns() {
    Set<String> names = ADA_MessageLiterals.classNames(
      'CaseGuard.check(Trigger.new); new OwnerRules().run(); System.debug(1); Database.insert(x); c.Name = \'x\';'
    );
    Assert.isTrue(names.contains('CaseGuard'));
    Assert.isTrue(names.contains('OwnerRules'));
    Assert.isFalse(names.contains('System'));
    Assert.isFalse(names.contains('Database'));
    Assert.isFalse(names.contains('Trigger'));
    Assert.isFalse(names.contains('c'));
    Assert.isTrue(ADA_MessageLiterals.classNames(null).isEmpty());
  }
}

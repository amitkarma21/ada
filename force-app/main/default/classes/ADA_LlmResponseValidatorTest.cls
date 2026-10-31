@IsTest
private class ADA_LlmResponseValidatorTest {
  private static void assertRejected(String content) {
    try {
      ADA_LlmResponseValidator.fromContent(content);
      Assert.fail('Should have been rejected: ' + content);
    } catch (ADA_LlmException e) {
      Assert.isTrue(e.getMessage().contains('rejected'));
    }
  }

  private static String answer(
    String explanation,
    String steps,
    String action
  ) {
    return '{"explanation":' +
      explanation +
      ',"fixSteps":' +
      steps +
      ',"suggestedAction":' +
      action +
      '}';
  }

  @IsTest
  static void aValidAnswerIsAccepted() {
    ADA_Explanation parsed = ADA_LlmResponseValidator.parse(
      ADA_LlmTestSupport.envelope(ADA_LlmTestSupport.VALID_CONTENT)
    );
    Assert.areEqual('The rule needs a future close date.', parsed.summary);
    Assert.areEqual(2, parsed.fixSteps.size());
    Assert.areEqual('LLM', parsed.source);
    Assert.areEqual(ADA_SuggestedAction.EXPLAIN_ONLY, parsed.suggestedAction);
  }

  @IsTest
  static void suggestedActionsMapToTheEnum() {
    Assert.areEqual(
      ADA_SuggestedAction.RAISE_WORK_ITEM,
      ADA_LlmResponseValidator.fromContent(answer('"x"', '[]', '"RAISE_BUG"'))
        .suggestedAction
    );
    Assert.areEqual(
      ADA_SuggestedAction.REQUEST_ACCESS,
      ADA_LlmResponseValidator.fromContent(
          answer('"x"', '[]', '"REQUEST_ACCESS"')
        )
        .suggestedAction
    );
  }

  @IsTest
  static void anEnvelopeThatIsNotChatCompletionsIsRejected() {
    for (
      String body : new List<String>{
        'not json',
        '{}',
        '{"choices":[]}',
        '{"choices":[{"message":{}}]}',
        '{"choices":[{"message":{"content":5}}]}',
        '[1]'
      }
    ) {
      try {
        ADA_LlmResponseValidator.parse(body);
        Assert.fail('Should have been rejected: ' + body);
      } catch (ADA_LlmException e) {
        Assert.isTrue(e.getMessage().contains('rejected'));
      }
    }
  }

  @IsTest
  static void contentThatIsNotTheAgreedObjectIsRejected() {
    assertRejected('this is not json');
    assertRejected('[]');
    assertRejected('"text"');
    assertRejected('{}');
    assertRejected('{"explanation":"x","fixSteps":[]}');
    assertRejected(
      '{"explanation":"x","fixSteps":[],"suggestedAction":"NONE","extra":"y"}'
    );
  }

  @IsTest
  static void anActionOutsideTheAllowlistIsRejected() {
    assertRejected(answer('"x"', '[]', '"DELETE_RECORD"'));
    assertRejected(answer('"x"', '[]', '"none"'));
    assertRejected(answer('"x"', '[]', '5'));
    assertRejected(answer('"x"', '[]', 'null'));
  }

  @IsTest
  static void wrongTypesAndLimitsAreRejected() {
    assertRejected(answer('5', '[]', '"NONE"'));
    assertRejected(answer('""', '[]', '"NONE"'));
    assertRejected(answer('"   "', '[]', '"NONE"'));
    assertRejected(answer('"x"', '"one"', '"NONE"'));
    assertRejected(answer('"x"', '[1]', '"NONE"'));
    assertRejected(answer('"x"', '[""]', '"NONE"'));
    assertRejected(answer('"x"', '["1","2","3","4","5","6"]', '"NONE"'));
    assertRejected(
      answer(
        '"' + 'a'.repeat(ADA_LlmResponseValidator.MAX_EXPLANATION + 1) + '"',
        '[]',
        '"NONE"'
      )
    );
    assertRejected(
      answer(
        '"x"',
        '["' + 'b'.repeat(ADA_LlmResponseValidator.MAX_STEP_LENGTH + 1) + '"]',
        '"NONE"'
      )
    );
  }

  @IsTest
  static void textAtTheLimitsIsAccepted() {
    ADA_Explanation parsed = ADA_LlmResponseValidator.fromContent(
      answer(
        '"' + 'a'.repeat(ADA_LlmResponseValidator.MAX_EXPLANATION) + '"',
        '["1","2","3","4","5"]',
        '"NONE"'
      )
    );
    Assert.areEqual(
      ADA_LlmResponseValidator.MAX_EXPLANATION,
      parsed.summary.length()
    );
    Assert.areEqual(5, parsed.fixSteps.size());
  }

  @IsTest
  static void linksInTheAnswerAreRejected() {
    assertRejected(
      answer('"Go to ' + 'https:' + '//evil.example/login now"', '[]', '"NONE"')
    );
    assertRejected(answer('"x"', '["Visit www.evil.example"]', '"NONE"'));
  }
}

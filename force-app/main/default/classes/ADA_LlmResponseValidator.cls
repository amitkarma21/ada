public with sharing class ADA_LlmResponseValidator {
  public static final Integer MAX_EXPLANATION = 1200;
  public static final Integer MAX_STEPS = 5;
  public static final Integer MAX_STEP_LENGTH = 300;
  public static final Set<String> ACTIONS = new Set<String>{
    'NONE',
    'RAISE_BUG',
    'REQUEST_ACCESS'
  };
  private static final Set<String> KEYS = new Set<String>{
    'explanation',
    'fixSteps',
    'suggestedAction'
  };

  public static ADA_Explanation parse(String responseBody) {
    return fromContent(content(responseBody));
  }

  public static ADA_Explanation fromContent(String content) {
    Map<String, Object> body;
    try {
      body = (Map<String, Object>) JSON.deserializeUntyped(content);
    } catch (Exception e) {
      throw invalid('the answer was not a JSON object');
    }
    if (body == null || !body.keySet().equals(KEYS)) {
      throw invalid('the answer did not have exactly the agreed fields');
    }
    String summary = text(body.get('explanation'), MAX_EXPLANATION);
    List<String> steps = steps(body.get('fixSteps'));
    Object action = body.get('suggestedAction');
    if (!(action instanceof String) || !ACTIONS.contains((String) action)) {
      throw invalid('the suggested action is not allowed');
    }
    ADA_Explanation explanation = new ADA_Explanation(summary, steps, 'LLM');
    explanation.suggestedAction = mapAction((String) action);
    return explanation;
  }

  private static String content(String responseBody) {
    try {
      Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(
        responseBody
      );
      List<Object> choices = (List<Object>) envelope.get('choices');
      Map<String, Object> first = (Map<String, Object>) choices[0];
      Map<String, Object> message = (Map<String, Object>) first.get('message');
      return (String) message.get('content');
    } catch (Exception e) {
      throw invalid('the response was not in the expected format');
    }
  }

  private static List<String> steps(Object raw) {
    if (!(raw instanceof List<Object>)) {
      throw invalid('fixSteps is not a list');
    }
    List<Object> items = (List<Object>) raw;
    if (items.size() > MAX_STEPS) {
      throw invalid('too many fix steps');
    }
    List<String> steps = new List<String>();
    for (Object item : items) {
      steps.add(text(item, MAX_STEP_LENGTH));
    }
    return steps;
  }

  private static String text(Object raw, Integer max) {
    if (!(raw instanceof String)) {
      throw invalid('a field is not text');
    }
    String value = ((String) raw).trim();
    if (value.length() == 0 || value.length() > max) {
      throw invalid('a text field is empty or too long');
    }
    if (value.contains('://') || value.containsIgnoreCase('www.')) {
      throw invalid('the answer contains a link');
    }
    return value;
  }

  private static ADA_SuggestedAction mapAction(String action) {
    if (action == 'RAISE_BUG') {
      return ADA_SuggestedAction.RAISE_WORK_ITEM;
    }
    if (action == 'REQUEST_ACCESS') {
      return ADA_SuggestedAction.REQUEST_ACCESS;
    }
    return ADA_SuggestedAction.EXPLAIN_ONLY;
  }

  private static ADA_LlmException invalid(String reason) {
    return new ADA_LlmException(
      'The model answer was rejected: ' + reason + '.'
    );
  }
}

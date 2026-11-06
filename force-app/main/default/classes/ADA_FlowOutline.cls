public with sharing class ADA_FlowOutline {
  private static final Pattern FIELD_NAME = Pattern.compile(
    '[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*'
  );
  private static final Pattern CUSTOM_LOGIC = Pattern.compile(
    '(?i)[0-9 ()]*(?:(?:and|or)[0-9 ()]*)*'
  );
  private static final Pattern DIGITS = Pattern.compile('[0-9]+');
  private static final Pattern RECORD_MERGE = Pattern.compile(
    '\\{!\\$Record\\.([A-Za-z0-9_.]+)\\}'
  );
  private static final String UNREADABLE = 'FLOW_CONDITION';
  private static final Integer MAX_FILTERS = 20;
  private static final Map<String, String> COMPARISONS = new Map<String, String>{
    'EqualTo' => '=',
    'NotEqualTo' => '<>',
    'GreaterThan' => '>',
    'GreaterThanOrEqualTo' => '>=',
    'LessThan' => '<',
    'LessThanOrEqualTo' => '<='
  };
  private static final Map<String, String> MOMENTS = new Map<String, String>{
    'RecordBeforeSave' => 'before a record is saved',
    'RecordAfterSave' => 'after a record is saved',
    'RecordBeforeDelete' => 'before a record is deleted'
  };
  private static final Map<String, String> EVENTS = new Map<String, String>{
    'Create' => ' (when it is created)',
    'Update' => ' (when it is updated)',
    'CreateAndUpdate' => ' (when it is created or updated)'
  };

  // What the explainer may know about a flow: when it runs and the condition it starts on,
  // with every text value and Id masked. Nothing else of the flow is kept.
  public class Outline {
    public String runsWhen;
    public String conditionMasked;
  }

  public static Outline read(Map<String, Object> metadata) {
    Outline outline = new Outline();
    if (
      metadata == null ||
      !(metadata.get('start') instanceof Map<String, Object>)
    ) {
      return outline;
    }
    Map<String, Object> start = (Map<String, Object>) metadata.get('start');
    String condition = condition(start);
    outline.conditionMasked = String.isBlank(condition)
      ? null
      : ADA_FormulaMasker.mask(condition);
    outline.runsWhen = runsWhen(start, outline.conditionMasked != null);
    return outline;
  }

  private static String runsWhen(
    Map<String, Object> start,
    Boolean hasCondition
  ) {
    String moment = MOMENTS.get(text(start.get('triggerType')));
    if (moment == null) {
      return null;
    }
    String event = EVENTS.get(text(start.get('recordTriggerType')));
    String phrase = moment + (event == null ? '' : event);
    if (
      hasCondition &&
      start.get('doesRequireRecordChangedToMeetCriteria') == true
    ) {
      phrase += ', and only when the change makes the record meet its entry conditions';
    }
    return phrase;
  }

  private static String condition(Map<String, Object> start) {
    String logic = text(start.get('filterLogic'));
    if (logic != null && logic.equalsIgnoreCase('formula_evaluates_to_true')) {
      String formula = text(start.get('filterFormula'));
      return formula == null
        ? null
        : RECORD_MERGE.matcher(formula).replaceAll('$1');
    }
    List<String> clauses = new List<String>();
    if (start.get('filters') instanceof List<Object>) {
      for (Object item : (List<Object>) start.get('filters')) {
        if (clauses.size() == MAX_FILTERS) {
          break;
        }
        clauses.add(
          item instanceof Map<String, Object>
            ? clause((Map<String, Object>) item)
            : UNREADABLE + '(UNKNOWN)'
        );
      }
    }
    if (clauses.isEmpty()) {
      return null;
    }
    if (logic == null || logic.equalsIgnoreCase('and')) {
      return String.join(clauses, ' && ');
    }
    if (logic.equalsIgnoreCase('or')) {
      return String.join(clauses, ' || ');
    }
    return custom(logic, clauses);
  }

  // Logic such as "1 AND (2 OR 3)". Anything else is dropped rather than guessed.
  private static String custom(String logic, List<String> clauses) {
    if (!CUSTOM_LOGIC.matcher(logic).matches()) {
      return null;
    }
    String result = '';
    Integer last = 0;
    Matcher numbers = DIGITS.matcher(logic);
    while (numbers.find()) {
      Integer index = Integer.valueOf(numbers.group());
      if (index < 1 || index > clauses.size()) {
        return null;
      }
      result +=
        symbols(logic.substring(last, numbers.start())) + clauses[index - 1];
      last = numbers.end();
    }
    return result + symbols(logic.substring(last));
  }

  private static String symbols(String logic) {
    return logic.replaceAll('(?i)\\band\\b', '&&')
      .replaceAll('(?i)\\bor\\b', '||');
  }

  private static String clause(Map<String, Object> filter) {
    String field = text(filter.get('field'));
    if (field == null || !FIELD_NAME.matcher(field).matches()) {
      return UNREADABLE + '(UNKNOWN)';
    }
    String operator = text(filter.get('operator'));
    Map<String, Object> value = filter.get(
        'value'
      ) instanceof Map<String, Object>
      ? (Map<String, Object>) filter.get('value')
      : new Map<String, Object>();
    if (operator == 'IsNull' && value.get('booleanValue') instanceof Boolean) {
      return value.get('booleanValue') == true
        ? 'ISBLANK(' + field + ')'
        : 'NOT(ISBLANK(' + field + '))';
    }
    String symbol = COMPARISONS.get(operator);
    String operand = literal(value);
    if (symbol == null || operand == null) {
      return UNREADABLE + '(' + field + ')';
    }
    return field + ' ' + symbol + ' ' + operand;
  }

  private static String literal(Map<String, Object> value) {
    if (value.get('stringValue') instanceof String) {
      return quoted((String) value.get('stringValue'));
    }
    if (value.get('booleanValue') instanceof Boolean) {
      return value.get('booleanValue') == true ? 'TRUE' : 'FALSE';
    }
    if (value.get('numberValue') != null) {
      String rendered = String.valueOf(value.get('numberValue'));
      return DIGITS.matcher(rendered.remove('.').remove('-')).matches()
        ? rendered
        : null;
    }
    for (String key : new List<String>{ 'dateValue', 'dateTimeValue' }) {
      if (value.get(key) instanceof String) {
        return quoted((String) value.get(key));
      }
    }
    return null;
  }

  private static String quoted(String value) {
    return '\'' + value.replace('\\', '\\\\').replace('\'', '\\\'') + '\'';
  }

  private static String text(Object value) {
    return value instanceof String ? (String) value : null;
  }
}

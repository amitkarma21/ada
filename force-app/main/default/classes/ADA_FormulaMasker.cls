public with sharing class ADA_FormulaMasker {
  // Quoted literals first so an id inside quotes is handled as one token.
  private static final Pattern TOKEN = Pattern.compile(
    '\'(?:[^\'\\\\]|\\\\.)*\'|"(?:[^"\\\\]|\\\\.)*"|\\b[A-Za-z0-9]{18}\\b|\\b[A-Za-z0-9]{15}\\b'
  );
  private static final Pattern IDENTIFIER = Pattern.compile(
    '[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*'
  );
  private static final Pattern PLACEHOLDER = Pattern.compile(
    '(?:TEXT|ID)_\\d+'
  );
  private static final Set<String> KEYWORDS = new Set<String>{
    'and',
    'or',
    'not',
    'true',
    'false',
    'null'
  };

  public static String mask(String formula) {
    if (String.isBlank(formula)) {
      return formula;
    }
    Map<String, String> seen = new Map<String, String>();
    Integer texts = 0;
    Integer ids = 0;
    String result = '';
    Integer last = 0;
    Matcher found = TOKEN.matcher(formula);
    while (found.find()) {
      String token = found.group();
      Boolean quoted = token.startsWith('\'') || token.startsWith('"');
      String content = quoted ? token.substring(1, token.length() - 1) : token;
      Boolean isId = looksLikeId(content);
      if (!quoted && !isId) {
        continue;
      }
      if (!seen.containsKey(token)) {
        seen.put(token, isId ? 'ID_' + (++ids) : 'TEXT_' + (++texts));
      }
      String placeholder = seen.get(token);
      String quote = quoted ? token.substring(0, 1) : '';
      result +=
        formula.substring(last, found.start()) +
        quote +
        placeholder +
        quote;
      last = found.end();
    }
    return result + formula.substring(last);
  }

  public static String referencedFields(String maskedFormula) {
    List<String> fields = new List<String>();
    if (String.isBlank(maskedFormula)) {
      return '';
    }
    Set<String> seen = new Set<String>();
    Matcher found = IDENTIFIER.matcher(maskedFormula);
    while (found.find()) {
      String name = found.group();
      Integer start = found.start();
      if (start > 0 && maskedFormula.substring(start - 1, start) == '$') {
        continue;
      }
      if (
        KEYWORDS.contains(name.toLowerCase()) ||
        PLACEHOLDER.matcher(name).matches() ||
        isCall(maskedFormula, found.end()) ||
        !seen.add(name)
      ) {
        continue;
      }
      fields.add(name);
    }
    return String.join(fields, ',');
  }

  private static Boolean isCall(String text, Integer position) {
    Integer index = position;
    while (
      index < text.length() && text.substring(index, index + 1).isWhitespace()
    ) {
      index++;
    }
    return index < text.length() && text.substring(index, index + 1) == '(';
  }

  private static Boolean looksLikeId(String value) {
    return (value.length() == 15 ||
      value.length() == 18) &&
      value.isAlphanumeric() &&
      value.containsAny('0123456789');
  }
}

public with sharing class ADA_MessageLiterals {
  private static final Pattern ADD_ERROR = Pattern.compile(
    '\\baddError\\s*\\('
  );
  private static final Pattern CLASS_CALL = Pattern.compile(
    '\\b([A-Za-z_][A-Za-z0-9_]*)\\s*\\.\\s*[A-Za-z_][A-Za-z0-9_]*\\s*\\(|\\bnew\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\('
  );
  private static final Set<String> NOT_CLASSES = new Set<String>{
    'trigger',
    'system',
    'database',
    'schema',
    'string',
    'math',
    'json',
    'label',
    'limits',
    'date',
    'datetime',
    'test',
    'userinfo',
    'this',
    'super'
  };
  private static final Integer QUOTE = 39;
  private static final Integer BACKSLASH = 92;
  private static final Integer OPEN = 40;
  private static final Integer CLOSE = 41;
  private static final Integer COMMA = 44;
  private static final Integer PLUS = 43;

  // Message templates passed to addError(...), one per call. A concatenated
  // variable part is shown as {} so the text can still be matched.
  public static List<String> fromAddError(String body) {
    List<String> templates = new List<String>();
    if (String.isBlank(body)) {
      return templates;
    }
    Matcher found = ADD_ERROR.matcher(body);
    while (found.find()) {
      String template = template(firstArgument(body, found.end()));
      if (template != null && !templates.contains(template)) {
        templates.add(template);
      }
    }
    return templates;
  }

  // Names that look like classes the code calls, for one more level of lookup.
  public static Set<String> classNames(String body) {
    Set<String> names = new Set<String>();
    if (String.isBlank(body)) {
      return names;
    }
    Matcher found = CLASS_CALL.matcher(body);
    while (found.find()) {
      String name = found.group(1) != null ? found.group(1) : found.group(2);
      if (name.length() > 2 && !NOT_CLASSES.contains(name.toLowerCase())) {
        names.add(name);
      }
    }
    return names;
  }

  private static String firstArgument(String body, Integer start) {
    Integer depth = 0;
    Boolean quoted = false;
    Integer index = start;
    while (index < body.length()) {
      Integer code = body.charAt(index);
      if (quoted) {
        index += code == BACKSLASH ? 2 : 1;
        quoted = !(code == QUOTE);
        continue;
      }
      if (code == QUOTE) {
        quoted = true;
      } else if (code == OPEN) {
        depth++;
      } else if (code == CLOSE || code == COMMA) {
        if (depth == 0) {
          break;
        }
        depth -= code == CLOSE ? 1 : 0;
      }
      index++;
    }
    return body.substring(start, Math.min(index, body.length()));
  }

  private static String template(String argument) {
    String text = '';
    String gap = '';
    Boolean sawLiteral = false;
    Integer depth = 0;
    Integer index = 0;
    while (index < argument.length()) {
      Integer code = argument.charAt(index);
      if (code == QUOTE && depth == 0) {
        Integer closing = literalEnd(argument, index);
        text +=
          gapMarker(gap) + unescape(argument.substring(index + 1, closing));
        gap = '';
        sawLiteral = true;
        index = closing + 1;
        continue;
      }
      depth += code == OPEN ? 1 : (code == CLOSE ? -1 : 0);
      gap += argument.substring(index, index + 1);
      index++;
    }
    return sawLiteral ? text + gapMarker(gap) : null;
  }

  private static Integer literalEnd(String text, Integer open) {
    Integer index = open + 1;
    while (index < text.length()) {
      Integer code = text.charAt(index);
      if (code == BACKSLASH) {
        index += 2;
        continue;
      }
      if (code == QUOTE) {
        return index;
      }
      index++;
    }
    return text.length();
  }

  private static String gapMarker(String gap) {
    String significant = gap.deleteWhitespace().replace('+', '');
    return significant == '' ? '' : '{}';
  }

  private static String unescape(String literal) {
    return literal.replace('\\\'', '\'').replace('\\\\', '\\');
  }
}

public with sharing class ADA_FormulaReader {
  public static final String MODE_ALL = 'ALL';
  public static final String MODE_ANY = 'ANY';
  public static final String MODE_ONE = 'ONE';
  public static final String UNREADABLE = 'another condition set by your admin';

  private static final Integer MAX_LENGTH = 2000;
  private static final Integer MAX_TOKENS = 500;
  private static final Integer MAX_DEPTH = 40;
  private static final Integer MAX_ITEMS = 10;
  private static final String WATCHED = 'the values the rule watches';
  private static final Set<String> COMPARISONS = new Set<String>{
    '<',
    '<=',
    '>',
    '>=',
    '=',
    '==',
    '!=',
    '<>'
  };
  private static final Set<String> TWO_CHAR = new Set<String>{
    '<=',
    '>=',
    '<>',
    '!=',
    '==',
    '&&',
    '||'
  };
  private static final String ONE_CHAR = '<>=!+-*/&^|';
  private static final Map<String, String> FLIPPED = new Map<String, String>{
    '<' => '>=',
    '>=' => '<',
    '>' => '<=',
    '<=' => '>',
    '=' => '!=',
    '!=' => '='
  };
  private static final Map<String, String> MIRRORED = new Map<String, String>{
    '<' => '>',
    '>' => '<',
    '<=' => '>=',
    '>=' => '<=',
    '=' => '=',
    '!=' => '!='
  };

  public class Reading {
    public String mode;
    public List<String> conditions = new List<String>();
    public List<String> fixes = new List<String>();
  }

  private class ReadException extends Exception {
  }

  private class Token {
    public String kind;
    public String text;
    public Token(String kind, String text) {
      this.kind = kind;
      this.text = text;
    }
  }

  private class Node {
    public String kind;
    public String text;
    public List<Node> kids = new List<Node>();
    public Node(String kind, String text) {
      this.kind = kind;
      this.text = text;
    }
  }

  private class Cond {
    public String mode;
    public List<Cond> items = new List<Cond>();
    public String text;
    public String fix;
  }

  public static Reading read(
    String maskedFormula,
    Map<String, String> labelsByApiName
  ) {
    if (String.isBlank(maskedFormula) || maskedFormula.length() > MAX_LENGTH) {
      return null;
    }
    try {
      return new Run(labelsByApiName).read(maskedFormula);
    } catch (ReadException unreadable) {
      return null;
    }
  }

  private static List<Token> tokenize(String source) {
    List<Token> tokens = new List<Token>();
    Integer size = source.length();
    Integer i = 0;
    while (i < size) {
      String ch = source.substring(i, i + 1);
      if (tokens.size() > MAX_TOKENS) {
        throw new ReadException('too long');
      }
      if (ch.isWhitespace()) {
        i++;
      } else if (ch == '"' || ch == '\'') {
        Integer closing = source.indexOf(ch, i + 1);
        if (closing < 0) {
          throw new ReadException('open quote');
        }
        tokens.add(new Token('str', source.substring(i + 1, closing)));
        i = closing + 1;
      } else if (ch.isNumeric()) {
        Integer j = i;
        while (j < size && isNumberChar(source.substring(j, j + 1))) {
          j++;
        }
        tokens.add(new Token('num', source.substring(i, j)));
        i = j;
      } else if (ch.isAlpha() || ch == '_') {
        Integer j = i;
        while (j < size && isWordChar(source.substring(j, j + 1))) {
          j++;
        }
        tokens.add(new Token('word', source.substring(i, j)));
        i = j;
      } else if (ch == '(' || ch == ')' || ch == ',') {
        tokens.add(new Token(ch, ch));
        i++;
      } else if (
        i + 1 < size && TWO_CHAR.contains(source.substring(i, i + 2))
      ) {
        tokens.add(new Token('op', source.substring(i, i + 2)));
        i += 2;
      } else if (ONE_CHAR.contains(ch)) {
        tokens.add(new Token('op', ch));
        i++;
      } else {
        throw new ReadException('unexpected character');
      }
    }
    return tokens;
  }

  private static Boolean isNumberChar(String ch) {
    return ch.isNumeric() || ch == '.';
  }

  private static Boolean isWordChar(String ch) {
    return ch.isAlphanumeric() || ch == '_' || ch == '.';
  }

  private class Run {
    private Map<String, String> labels = new Map<String, String>();
    private List<Token> tokens;
    private Integer pos = 0;
    private Integer depth = 0;
    private Integer understood = 0;

    public Run(Map<String, String> labelsByApiName) {
      if (labelsByApiName != null) {
        for (String apiName : labelsByApiName.keySet()) {
          if (apiName != null) {
            labels.put(apiName.toLowerCase(), labelsByApiName.get(apiName));
          }
        }
      }
    }

    public Reading read(String source) {
      tokens = tokenize(source);
      Node root = parseOr();
      if (pos < tokens.size()) {
        throw new ReadException('trailing text');
      }
      Cond top = translate(root, false);
      if (understood == 0) {
        return null;
      }
      return build(top);
    }

    private Reading build(Cond top) {
      Reading result = new Reading();
      List<Cond> items = top.mode == null ? new List<Cond>{ top } : top.items;
      result.mode = top.mode == null ? MODE_ONE : top.mode;
      for (Cond item : items) {
        String described = describe(item);
        if (
          !result.conditions.contains(described) &&
          result.conditions.size() < MAX_ITEMS
        ) {
          result.conditions.add(described);
        }
        if (
          item.mode == null &&
          item.fix != null &&
          !result.fixes.contains(item.fix) &&
          result.fixes.size() < MAX_ITEMS
        ) {
          result.fixes.add(item.fix);
        }
      }
      return result;
    }

    private String describe(Cond cond) {
      if (cond.mode == null) {
        return cond.text;
      }
      List<String> parts = new List<String>();
      for (Cond item : cond.items) {
        parts.add(describe(item));
      }
      return '(' +
        String.join(parts, cond.mode == MODE_ALL ? ' and ' : ' or ') +
        ')';
    }

    private Token peek() {
      return pos < tokens.size() ? tokens[pos] : null;
    }

    private Token take() {
      if (pos >= tokens.size()) {
        throw new ReadException('ran out of text');
      }
      return tokens[pos++];
    }

    private Boolean atOperator(String text) {
      Token next = peek();
      return next != null && next.kind == 'op' && next.text == text;
    }

    private void enter() {
      depth++;
      if (depth > MAX_DEPTH) {
        throw new ReadException('too deep');
      }
    }

    private Node parseOr() {
      enter();
      Node first = parseAnd();
      Node combined = new Node('OR', null);
      combined.kids.add(first);
      while (atOperator('||')) {
        pos++;
        combined.kids.add(parseAnd());
      }
      depth--;
      return combined.kids.size() == 1 ? first : combined;
    }

    private Node parseAnd() {
      Node first = parseComparison();
      Node combined = new Node('AND', null);
      combined.kids.add(first);
      while (atOperator('&&')) {
        pos++;
        combined.kids.add(parseComparison());
      }
      return combined.kids.size() == 1 ? first : combined;
    }

    private Node parseComparison() {
      Node left = parseSum();
      Token next = peek();
      if (
        next != null &&
        next.kind == 'op' &&
        COMPARISONS.contains(next.text)
      ) {
        pos++;
        Node compare = new Node('CMP', normalise(next.text));
        compare.kids.add(left);
        compare.kids.add(parseSum());
        return compare;
      }
      return left;
    }

    private Node parseSum() {
      Node left = parseProduct();
      while (atOperator('+') || atOperator('-') || atOperator('&')) {
        pos++;
        Node sum = new Node('BIN', null);
        sum.kids.add(left);
        sum.kids.add(parseProduct());
        left = sum;
      }
      return left;
    }

    private Node parseProduct() {
      Node left = parseUnary();
      while (atOperator('*') || atOperator('/') || atOperator('^')) {
        pos++;
        Node product = new Node('BIN', null);
        product.kids.add(left);
        product.kids.add(parseUnary());
        left = product;
      }
      return left;
    }

    private Node parseUnary() {
      enter();
      Node result;
      if (atOperator('!')) {
        pos++;
        result = new Node('NOT', null);
        result.kids.add(parseUnary());
      } else if (atOperator('-')) {
        pos++;
        Node nested = parseUnary();
        if (nested.kind == 'NUM') {
          result = new Node('NUM', '-' + nested.text);
        } else {
          result = new Node('BIN', null);
          result.kids.add(nested);
        }
      } else {
        result = parsePrimary();
      }
      depth--;
      return result;
    }

    private Node parsePrimary() {
      Token t = take();
      if (t.kind == '(') {
        Node nested = parseOr();
        expect(')');
        return nested;
      }
      if (t.kind == 'num') {
        return new Node('NUM', t.text);
      }
      if (t.kind == 'str') {
        return new Node('STR', t.text);
      }
      if (t.kind != 'word') {
        throw new ReadException('unexpected token');
      }
      Token next = peek();
      if (next != null && next.kind == '(') {
        pos++;
        return parseCall(t.text.toUpperCase());
      }
      String upper = t.text.toUpperCase();
      if (upper == 'TRUE' || upper == 'FALSE') {
        return new Node('BOOL', upper);
      }
      return new Node('ID', t.text);
    }

    private Node parseCall(String name) {
      List<Node> args = new List<Node>();
      Token next = peek();
      if (next != null && next.kind == ')') {
        pos++;
      } else {
        while (true) {
          args.add(parseOr());
          Token separator = take();
          if (separator.kind == ')') {
            break;
          }
          if (separator.kind != ',') {
            throw new ReadException('expected a comma');
          }
        }
      }
      String kind = name == 'AND' ||
        name == 'OR' ||
        name == 'NOT'
        ? name
        : 'CALL';
      if (
        kind != 'CALL' &&
        (args.isEmpty() || (kind == 'NOT' && args.size() != 1))
      ) {
        throw new ReadException('bad argument count');
      }
      Node invocation = new Node(kind, name);
      invocation.kids = args;
      return invocation;
    }

    private void expect(String kind) {
      if (take().kind != kind) {
        throw new ReadException('expected ' + kind);
      }
    }

    private String normalise(String op) {
      if (op == '==') {
        return '=';
      }
      return op == '<>' ? '!=' : op;
    }

    private Cond translate(Node node, Boolean negate) {
      if (node.kind == 'AND' || node.kind == 'OR') {
        Boolean everything = (node.kind == 'AND') != negate;
        return combine(everything ? MODE_ALL : MODE_ANY, node.kids, negate);
      }
      if (node.kind == 'NOT') {
        return translate(node.kids[0], !negate);
      }
      if (node.kind == 'CMP') {
        return compare(node, negate);
      }
      if (node.kind == 'ID') {
        return leaf(
          label(node.text) + (negate ? ' is not ticked' : ' is ticked'),
          null
        );
      }
      if (node.kind == 'CALL') {
        return translateCall(node, negate);
      }
      return unknown();
    }

    private Cond combine(String mode, List<Node> kids, Boolean negate) {
      Cond result = new Cond();
      result.mode = mode;
      for (Node kid : kids) {
        Cond part = translate(kid, negate);
        if (part.mode == mode) {
          result.items.addAll(part.items);
        } else {
          result.items.add(part);
        }
      }
      return result.items.size() == 1 ? result.items[0] : result;
    }

    private Cond translateCall(Node node, Boolean negate) {
      String name = node.text;
      if ((name == 'ISBLANK' || name == 'ISNULL') && node.kids.size() == 1) {
        String field = fieldOf(node.kids[0]);
        if (field != null) {
          return negate
            ? leaf(field + ' is filled in', null)
            : leaf(field + ' is empty', 'Enter a value in ' + field + '.');
        }
      }
      if (name == 'ISPICKVAL' && node.kids.size() == 2) {
        String field = fieldOf(node.kids[0]);
        if (field != null) {
          return leaf(
            field +
              (negate ? ' is not one of ' : ' is set to one of ') +
              WATCHED,
            null
          );
        }
      }
      return unknown();
    }

    private Cond compare(Node node, Boolean negate) {
      Node left = node.kids[0];
      Node right = node.kids[1];
      String op = node.text;
      if (fieldOf(left) == null && fieldOf(right) != null) {
        Node swap = left;
        left = right;
        right = swap;
        op = MIRRORED.get(op);
      }
      String field = fieldOf(left);
      if (field == null) {
        return unknown();
      }
      if (negate) {
        op = FLIPPED.get(op);
      }
      if (right.kind == 'CALL' && right.text == 'TODAY') {
        return againstToday(field, op);
      }
      if (right.kind == 'NUM') {
        return againstNumber(field, op, right.text);
      }
      if (right.kind == 'BOOL' && (op == '=' || op == '!=')) {
        Boolean ticked = (right.text == 'TRUE') == (op == '=');
        return leaf(field + (ticked ? ' is ticked' : ' is not ticked'), null);
      }
      if (right.kind == 'STR' && (op == '=' || op == '!=')) {
        return leaf(
          field +
            (op == '=' ? ' is set to one of ' : ' is not one of ') +
            WATCHED,
          null
        );
      }
      String other = fieldOf(right);
      if (other != null) {
        return leaf(field + ' ' + words(op) + ' ' + other, null);
      }
      return unknown();
    }

    private Cond againstToday(String field, String op) {
      if (op == '<') {
        return leaf(
          field + ' is earlier than today',
          'Set ' + field + ' to today or a later date.'
        );
      }
      if (op == '<=') {
        return leaf(
          field + ' is today or earlier',
          'Set ' + field + ' to a date after today.'
        );
      }
      if (op == '>') {
        return leaf(
          field + ' is later than today',
          'Set ' + field + ' to today or an earlier date.'
        );
      }
      if (op == '>=') {
        return leaf(
          field + ' is today or later',
          'Set ' + field + ' to a date before today.'
        );
      }
      return op == '='
        ? leaf(
            field + ' is today',
            'Set ' + field + ' to a date other than today.'
          )
        : leaf(field + ' is not today', 'Set ' + field + ' to today.');
    }

    private Cond againstNumber(String field, String op, String value) {
      if (op == '>') {
        return leaf(
          field + ' is greater than ' + value,
          'Make ' + field + ' ' + value + ' or less.'
        );
      }
      if (op == '>=') {
        return leaf(
          field + ' is ' + value + ' or more',
          'Make ' + field + ' less than ' + value + '.'
        );
      }
      if (op == '<') {
        return leaf(
          field + ' is less than ' + value,
          'Make ' + field + ' ' + value + ' or more.'
        );
      }
      if (op == '<=') {
        return leaf(
          field + ' is ' + value + ' or less',
          'Make ' + field + ' more than ' + value + '.'
        );
      }
      return op == '='
        ? leaf(
            field + ' is ' + value,
            'Change ' + field + ' to a value other than ' + value + '.'
          )
        : leaf(
            field + ' is not ' + value,
            'Set ' + field + ' to ' + value + '.'
          );
    }

    private String words(String op) {
      if (op == '<') {
        return 'is less than';
      }
      if (op == '<=') {
        return 'is less than or equal to';
      }
      if (op == '>') {
        return 'is greater than';
      }
      if (op == '>=') {
        return 'is greater than or equal to';
      }
      return op == '=' ? 'is the same as' : 'is different from';
    }

    private String fieldOf(Node node) {
      if (node.kind == 'ID') {
        return label(node.text);
      }
      if (
        node.kind == 'CALL' &&
        node.kids.size() == 1 &&
        (node.text == 'TEXT' ||
        node.text == 'VALUE' ||
        node.text == 'DATEVALUE')
      ) {
        return fieldOf(node.kids[0]);
      }
      return null;
    }

    private String label(String apiName) {
      String name = apiName.substringAfterLast('.');
      if (String.isBlank(name)) {
        name = apiName;
      }
      String known = labels.get(name.toLowerCase());
      if (String.isNotBlank(known)) {
        return known;
      }
      return name.replace('__c', '')
        .replace('__r', '')
        .replace('_', ' ')
        .replaceAll('([a-z0-9])([A-Z])', '$1 $2')
        .trim();
    }

    private Cond leaf(String text, String fix) {
      understood++;
      Cond result = new Cond();
      result.text = text;
      result.fix = fix;
      return result;
    }

    private Cond unknown() {
      Cond result = new Cond();
      result.text = UNREADABLE;
      return result;
    }
  }
}

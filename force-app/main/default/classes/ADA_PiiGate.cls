public with sharing class ADA_PiiGate {
  public class Result {
    public String text;
    public Set<String> kinds = new Set<String>();

    public Boolean changed() {
      return !kinds.isEmpty();
    }
  }

  private static final Integer MAX_NAME_CANDIDATES = 40;
  private static final Integer MAX_NAME_WORDS = 4;
  private static final Integer MIN_NAME_LENGTH = 3;
  private static final Integer MAX_NAME_MATCHES = 200;
  private static final String NAME_TOKEN = '[NAME]';
  private static final Map<String, String> TOKENS = new Map<String, String>{
    'Card_Number' => '[CARD]',
    'Email' => '[EMAIL]',
    'Phone_AU' => '[PHONE]',
    'Tax_File_Number' => '[TFN]'
  };
  private static final List<Integer> TFN_WEIGHTS = new List<Integer>{
    1,
    4,
    3,
    7,
    5,
    8,
    6,
    9,
    10
  };
  private static final Pattern CAPITALISED_RUN = Pattern.compile(
    '[A-Z][A-Za-z0-9&\'-]*(?: +[A-Z][A-Za-z0-9&\'-]*)*'
  );

  @TestVisible
  private static List<ADA_Pii_Pattern__mdt> patternOverride;

  public static List<ADA_Pii_Pattern__mdt> activePatterns() {
    List<ADA_Pii_Pattern__mdt> all = patternOverride != null
      ? patternOverride
      : ADA_Pii_Pattern__mdt.getAll().values();
    Map<String, ADA_Pii_Pattern__mdt> byName = new Map<String, ADA_Pii_Pattern__mdt>();
    for (ADA_Pii_Pattern__mdt pattern : all) {
      if (pattern.Active__c == true && !String.isBlank(pattern.Regex__c)) {
        byName.put(pattern.DeveloperName, pattern);
      }
    }
    List<String> names = new List<String>(byName.keySet());
    names.sort();
    List<ADA_Pii_Pattern__mdt> ordered = new List<ADA_Pii_Pattern__mdt>();
    for (String name : names) {
      ordered.add(byName.get(name));
    }
    return ordered;
  }

  // Patterns and Account / Contact names. Runs two queries when the text holds a capitalised word.
  public static Result scrub(String text) {
    Result result = scrubPatterns(text);
    if (!String.isBlank(result.text)) {
      result.text = scrubNames(result);
    }
    return result;
  }

  // Patterns only: no queries.
  public static Result scrubPatterns(String text) {
    Result result = new Result();
    result.text = text;
    if (String.isBlank(text)) {
      return result;
    }
    for (ADA_Pii_Pattern__mdt pattern : activePatterns()) {
      Pattern compiled = compile(pattern.Regex__c);
      if (compiled != null) {
        result.text = replaceHits(result, compiled, pattern.DeveloperName);
      }
    }
    return result;
  }

  public static Set<String> detect(String text) {
    return scrubPatterns(text).kinds;
  }

  private static Pattern compile(String regex) {
    try {
      return Pattern.compile(regex);
    } catch (Exception e) {
      return null;
    }
  }

  private static String replaceHits(
    Result result,
    Pattern compiled,
    String patternName
  ) {
    String token = TOKENS.containsKey(patternName)
      ? TOKENS.get(patternName)
      : '[REDACTED]';
    String text = result.text;
    Matcher found = compiled.matcher(text);
    String rebuilt = '';
    Integer last = 0;
    while (found.find()) {
      if (found.end() == found.start() || !valid(patternName, found.group())) {
        continue;
      }
      rebuilt += text.substring(last, found.start()) + token;
      last = found.end();
      result.kinds.add(token.substring(1, token.length() - 1));
    }
    return rebuilt + text.substring(last);
  }

  private static Boolean valid(String patternName, String hit) {
    String digits = hit.replaceAll('[^0-9]', '');
    if (patternName == 'Card_Number') {
      return digits.length() >= 13 && digits.length() <= 19 && luhn(digits);
    }
    if (patternName == 'Tax_File_Number') {
      return digits.length() == 9 && tfnChecksum(digits);
    }
    return true;
  }

  private static Boolean luhn(String digits) {
    Integer sum = 0;
    Boolean doubled = false;
    for (Integer i = digits.length() - 1; i >= 0; i--) {
      Integer digit = Integer.valueOf(digits.substring(i, i + 1));
      if (doubled) {
        digit = digit * 2;
        if (digit > 9) {
          digit -= 9;
        }
      }
      sum += digit;
      doubled = !doubled;
    }
    return Math.mod(sum, 10) == 0;
  }

  private static Boolean tfnChecksum(String digits) {
    Integer sum = 0;
    for (Integer i = 0; i < TFN_WEIGHTS.size(); i++) {
      sum += Integer.valueOf(digits.substring(i, i + 1)) * TFN_WEIGHTS[i];
    }
    return Math.mod(sum, 11) == 0;
  }

  // Only exact, case-sensitive Account and Contact names are replaced, and only names the
  // running user can read: a lower-case typing of a name is not caught.
  private static String scrubNames(Result result) {
    List<String> candidates = nameCandidates(result.text);
    if (candidates.isEmpty()) {
      return result.text;
    }
    Set<String> known = new Set<String>();
    try {
      for (Account row : [
        SELECT Name
        FROM Account
        WHERE Name IN :candidates
        WITH USER_MODE
        LIMIT :MAX_NAME_MATCHES
      ]) {
        known.add(row.Name);
      }
    } catch (QueryException e) {
      known.addAll(new Set<String>());
    }
    try {
      for (Contact row : [
        SELECT Name
        FROM Contact
        WHERE Name IN :candidates
        WITH USER_MODE
        LIMIT :MAX_NAME_MATCHES
      ]) {
        known.add(row.Name);
      }
    } catch (QueryException e) {
      known.addAll(new Set<String>());
    }
    List<String> longestFirst = new List<String>(known);
    longestFirst.sort();
    String text = result.text;
    for (Integer i = longestFirst.size() - 1; i >= 0; i--) {
      if (text.contains(longestFirst[i])) {
        text = text.replace(longestFirst[i], NAME_TOKEN);
        result.kinds.add('NAME');
      }
    }
    return text;
  }

  private static List<String> nameCandidates(String text) {
    Set<String> candidates = new Set<String>();
    Matcher runs = CAPITALISED_RUN.matcher(text);
    while (runs.find() && candidates.size() < MAX_NAME_CANDIDATES) {
      List<String> words = runs.group().split(' +');
      for (Integer start = 0; start < words.size(); start++) {
        for (
          Integer length = 1;
          length <= MAX_NAME_WORDS &&
          start + length <= words.size();
          length++
        ) {
          String candidate = String.join(
            slice(words, start, start + length),
            ' '
          );
          if (candidate.length() >= MIN_NAME_LENGTH) {
            candidates.add(candidate);
          }
        }
      }
    }
    return new List<String>(candidates);
  }

  private static List<String> slice(
    List<String> words,
    Integer startAt,
    Integer endAt
  ) {
    List<String> part = new List<String>();
    for (Integer i = startAt; i < endAt; i++) {
      part.add(words[i]);
    }
    return part;
  }
}

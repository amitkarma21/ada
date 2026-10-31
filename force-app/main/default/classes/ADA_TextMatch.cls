public with sharing class ADA_TextMatch {
  // An approximate match never reaches 1, so an exact match always outranks it.
  public static final Decimal CEILING = 0.95;
  public static final Integer MIN_TEMPLATE_WORDS = 3;
  public static final Integer MAX_WORDS = 120;

  // Both inputs are already normalised. Every template word must appear in the message, in
  // order (recall, cubed so a single missing word of ten drops the match below the threshold).
  // Extra message words are tolerated and only mildly penalised: they are usually the values
  // that a flow or Apex message merges into a fixed template.
  public static Decimal score(String message, String template) {
    if (String.isBlank(message) || String.isBlank(template)) {
      return 0;
    }
    if (message == template) {
      return 1;
    }
    List<String> wanted = template.split(' ');
    List<String> given = message.split(' ');
    if (
      wanted.size() < MIN_TEMPLATE_WORDS ||
      wanted.size() > MAX_WORDS ||
      given.size() > MAX_WORDS
    ) {
      return 0;
    }
    Decimal common = commonLength(wanted, given);
    Decimal recall = common / wanted.size();
    Decimal precision = common / given.size();
    Decimal score =
      CEILING *
      recall *
      recall *
      recall *
      (0.5 + 0.5 * precision);
    return score.setScale(4);
  }

  public static Decimal scoreRow(String message, ADA_Metadata_Index__c row) {
    Decimal best = 0;
    if (String.isBlank(row.Message_Normalised__c)) {
      return best;
    }
    for (String line : row.Message_Normalised__c.split('\n')) {
      best = Math.max(best, score(message, line.trim()));
    }
    return best;
  }

  private static Integer commonLength(List<String> a, List<String> b) {
    List<Integer> previous = new List<Integer>();
    for (Integer j = 0; j <= b.size(); j++) {
      previous.add(0);
    }
    for (Integer i = 1; i <= a.size(); i++) {
      List<Integer> current = new List<Integer>{ 0 };
      for (Integer j = 1; j <= b.size(); j++) {
        if (a[i - 1] == b[j - 1]) {
          current.add(previous[j - 1] + 1);
        } else {
          current.add(Math.max(previous[j], current[j - 1]));
        }
      }
      previous = current;
    }
    return previous[b.size()];
  }
}

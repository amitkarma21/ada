public with sharing class ADA_MessageNormaliser {
  private static final Pattern WRAPPER = Pattern.compile(
    '(?is)^.*?first error:\\s*'
  );
  private static final Pattern STATUS_CODE = Pattern.compile(
    '^[A-Z][A-Z_]{3,}\\s*[,:]\\s*'
  );
  private static final Pattern FIELD_SUFFIX = Pattern.compile(
    ':?\\s*\\[[^\\]]*\\]\\s*$'
  );
  private static final Pattern MERGE_FIELD = Pattern.compile('\\{![^}]*\\}');
  private static final Pattern APOSTROPHES = Pattern.compile('[\'\u2019]');
  private static final Pattern NON_WORD = Pattern.compile('[^a-z0-9]+');

  public static String normalise(String message) {
    if (String.isBlank(message)) {
      return '';
    }
    String text = message.trim();
    text = WRAPPER.matcher(text).replaceFirst('');
    text = STATUS_CODE.matcher(text).replaceFirst('');
    text = FIELD_SUFFIX.matcher(text).replaceFirst('');
    text = MERGE_FIELD.matcher(text).replaceAll(' ');
    text = APOSTROPHES.matcher(text).replaceAll('').toLowerCase();
    return NON_WORD.matcher(text).replaceAll(' ').trim();
  }

  public static String normaliseLines(String messages) {
    List<String> lines = new List<String>();
    if (String.isBlank(messages)) {
      return '';
    }
    for (String line : messages.split('\n')) {
      String normalised = normalise(line);
      if (normalised != '') {
        lines.add(normalised);
      }
    }
    return String.join(lines, '\n');
  }
}

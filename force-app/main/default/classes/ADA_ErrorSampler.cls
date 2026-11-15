public with sharing class ADA_ErrorSampler {
  public static final Integer MAX_SAMPLE = 200;

  private static final Pattern DIGITS = Pattern.compile('[0-9]+');
  private static final Pattern SPACES = Pattern.compile('\\s+');

  // A short, anonymous form of an error ADA could not explain: personal data scrubbed,
  // wrapper and punctuation gone, no digits, so repeats can be counted without keeping
  // anything about a record. Returns null when nothing useful is left.
  public static String sample(String message) {
    if (String.isBlank(message)) {
      return null;
    }
    String scrubbed = ADA_PiiGate.scrub(message).text;
    String text = ADA_MessageNormaliser.normalise(scrubbed);
    text = DIGITS.matcher(text).replaceAll(' ');
    text = SPACES.matcher(text).replaceAll(' ').trim();
    if (text.length() > MAX_SAMPLE) {
      text = text.left(MAX_SAMPLE).trim();
    }
    return text == '' ? null : text;
  }
}

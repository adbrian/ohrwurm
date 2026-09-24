import '../data/models.dart';

/// `A1 · Chapter 2` or `A1 · Notebook 3` (APP_SPEC 4.3).
String packLabel(String level, String kind, int number) =>
    '${level.toUpperCase()} · ${kind == 'notebook' ? 'Notebook' : 'Chapter'} $number';

/// The pack's heading: its title if it has one, else its label (APP_SPEC 4.3).
String packHeading(PackInput p) => p.title ?? packLabel(p.level, p.kind, p.number);

/// The meta line under a pack's heading: the label, then the word count. The label is left
/// out when it's already the heading (DESIGN 4).
String packMeta(PackInput p, int words) =>
    [if (p.title != null) packLabel(p.level, p.kind, p.number), wordCount(words)].join(' · ');

String wordCount(int n) => n == 1 ? '1 word' : '$n words';

PackInput packInputOf(Pack p) => PackInput(
  packId: p.packId,
  level: p.level,
  kind: p.kind,
  number: p.number,
  title: p.title,
  audioFormat: p.audioFormat,
  generatedAt: p.generatedAt,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped whenever any data write happens; consumers use this to re-fetch.
final dataRevisionProvider = StateProvider<int>((_) => 0);

void bumpDataRevisionCounter(Ref ref) {
  ref.read(dataRevisionProvider.notifier).state++;
}

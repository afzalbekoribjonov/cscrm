import 'dart:async';

/// Ikki oqimning ENG SO'NGGI qiymatlarini birlashtiradi.
///
/// Dart'da tayyor `combineLatest` yo'q, `rxdart` esa faqat shu uchun
/// qo'shiladigan katta bog'liqlik bo'lardi. Bu yerda kerakli minimal
/// xatti-harakat: har ikkala oqimdan kamida bittadan qiymat kelgach,
/// istalgan biri yangilanganda natija qayta hisoblanadi.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;

  void emit() {
    if (hasA && hasB) {
      controller.add(combine(latestA as A, latestB as B));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen(
        (value) {
          latestA = value;
          hasA = true;
          emit();
        },
        onError: controller.addError,
      );
      subB = b.listen(
        (value) {
          latestB = value;
          hasB = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );

  return controller.stream;
}

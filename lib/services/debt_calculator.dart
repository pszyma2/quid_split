class TransferAction {
  final String fromUserId;
  final String toUserId;
  final double amount;

  TransferAction({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });
}

class DebtCalculator {
  /// Oblicza absolutne minimum przelewów potrzebnych do wyrównania rachunków w grupie.
  /// Przyjmuje mapę wydatków {userId: totalAmountPaid} oraz pełną listę uczestników (żeby uwzględnić tych, co nic nie zapłacili).
  static List<TransferAction> calculateMinimalTransfers({
    required Map<String, double> userTotalPayments,
    required List<String> allMemberIds,
  }) {
    // 1. Obliczamy całkowity koszt wyjazdu
    double totalTripCost = 0;
    userTotalPayments.forEach((_, amount) => totalTripCost += amount);

    if (totalTripCost == 0 || allMemberIds.isEmpty) {
      return []; // Nie ma czego rozliczać
    }

    // 2. Obliczamy ile każdy powinien zapłacić "na głowę"
    double perPersonShare = totalTripCost / allMemberIds.length;

    // 3. Wyliczamy bilans każdego użytkownika
    // Dodatni bilans (Wierzyciel) - ma dostać pieniądze
    // Ujemny bilans (Dłużnik) - musi oddać pieniądze
    Map<String, double> balances = {};
    for (String memberId in allMemberIds) {
      double paid = userTotalPayments[memberId] ?? 0.0;
      balances[memberId] = paid - perPersonShare;
    }

    // 4. Dzielimy na dłużników i wierzycieli
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    balances.forEach((userId, balance) {
      // Zaokrąglamy do 2 miejsc po przecinku, żeby uniknąć błędów zmiennoprzecinkowych z rzędu 0.000000001
      double roundedBalance = double.parse(balance.toStringAsFixed(2));
      if (roundedBalance < 0) {
        debtors.add(MapEntry(userId, roundedBalance.abs()));
      } else if (roundedBalance > 0) {
        creditors.add(MapEntry(userId, roundedBalance));
      }
    });

    // Sortujemy malejąco, żeby najwięksi dłużnicy oddawali największym wierzycielom (optymalizacja)
    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    List<TransferAction> finalTransfers = [];

    int i = 0; // Index dłużnika
    int j = 0; // Index wierzyciela

    // 5. Algorytm zachłanny - parowanie przelewów
    while (i < debtors.length && j < creditors.length) {
      String debtorId = debtors[i].key;
      double debtAmount = debtors[i].value;

      String creditorId = creditors[j].key;
      double creditAmount = creditors[j].value;

      // Ustalamy kwotę przelewu (to mniejsza z dwóch wartości)
      double transferAmount = debtAmount < creditAmount ? debtAmount : creditAmount;
      
      // Odrzucamy mikroskopijne przelewy poniżej 1 pensa
      if (transferAmount > 0.009) {
        finalTransfers.add(TransferAction(
          fromUserId: debtorId,
          toUserId: creditorId,
          amount: double.parse(transferAmount.toStringAsFixed(2)),
        ));
      }

      // Aktualizujemy pozostałe salda
      debtors[i] = MapEntry(debtorId, debtAmount - transferAmount);
      creditors[j] = MapEntry(creditorId, creditAmount - transferAmount);

      // Jeśli dłużnik spłacił wszystko, bierzemy następnego
      if (debtors[i].value < 0.01) {
        i++;
      }
      // Jeśli wierzyciel dostał wszystko, bierzemy następnego
      if (creditors[j].value < 0.01) {
        j++;
      }
    }

    return finalTransfers;
  }
}
import 'package:flutter/foundation.dart';

class Participant {
  final String id;
  final String name;

  Participant({
    required this.id,
    required this.name,
  });

  Participant copyWith({
    String? id,
    String? name,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

class BillItem {
  final String id;
  final String name;
  final double price;
  final List<String> sharedByIds;

  BillItem({
    required this.id,
    required this.name,
    required this.price,
    required this.sharedByIds,
  });

  double get pricePerPerson {
    if (sharedByIds.isEmpty) return 0.0;
    return price / sharedByIds.length;
  }

  BillItem copyWith({
    String? id,
    String? name,
    double? price,
    List<String>? sharedByIds,
  }) {
    return BillItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      sharedByIds: sharedByIds ?? this.sharedByIds,
    );
  }
}

class Bill {
  final String id;
  final String restaurantName;
  final DateTime date;
  final List<Participant> participants;
  final List<BillItem> items;
  final double serviceChargeAmount;
  final double tipAmount;

  Bill({
    required this.id,
    required this.restaurantName,
    required this.date,
    required this.participants,
    required this.items,
    this.serviceChargeAmount = 0.0,
    this.tipAmount = 0.0,
  });

  double get subtotal {
    double total = 0.0;
    for (var item in items) {
      total += item.price;
    }
    return total;
  }

  double get totalAmount {
    return subtotal + serviceChargeAmount + tipAmount;
  }

  double calculateOwedAmountFor(String participantId) {
    double personSubtotal = 0.0;

    for (var item in items) {
      if (item.sharedByIds.contains(participantId)) {
        personSubtotal += item.pricePerPerson;
      }
    }

    if (personSubtotal == 0.0 || subtotal == 0.0) return 0.0;

    double proportion = personSubtotal / subtotal;
    double personShareOfExtras = (serviceChargeAmount + tipAmount) * proportion;

    return personSubtotal + personShareOfExtras;
  }

  Bill copyWith({
    String? id,
    String? restaurantName,
    DateTime? date,
    List<Participant>? participants,
    List<BillItem>? items,
    double? serviceChargeAmount,
    double? tipAmount,
  }) {
    return Bill(
      id: id ?? this.id,
      restaurantName: restaurantName ?? this.restaurantName,
      date: date ?? this.date,
      participants: participants ?? this.participants,
      items: items ?? this.items,
      serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
      tipAmount: tipAmount ?? this.tipAmount,
    );
  }
}